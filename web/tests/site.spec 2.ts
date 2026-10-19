import { test, expect } from "@playwright/test";
import { readFile } from "node:fs/promises";
const pages = ["", "invite", "privacy", "terms", "support", "privacy-choices", "delete-account"];
const normalize = (text: string) => text.replace(/\s+/g, " ").trim();
for (const name of pages) test(`public ${name || "home"}: content, navigation, desktop and phone`, async ({ page }) => {
  const errors: string[] = []; page.on("pageerror", (error) => errors.push(error.message));
  await page.route("**/*", (route) => new URL(route.request().url()).hostname === "127.0.0.1" ? route.continue() : route.abort());
  const original = await readFile(new URL(`../site/source/${name ? name + "/" : ""}index.html`, import.meta.url), "utf8");
  for (const width of [1440,390]) {
    await page.setViewportSize({ width, height: 1000 });
    const response = await page.goto(name ? `/${name}/` : "/"); expect(response?.status()).toBe(200);
    await expect(page.locator("h1")).toBeVisible(); await expect(page.locator('.site-nav a[href="/app/"]')).toHaveText("כניסה למטפלים");
    expect(await page.locator("html").getAttribute("dir")).toBe("rtl");
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    const sourceText = await page.evaluate((html) => new DOMParser().parseFromString(html, "text/html").querySelector("article")!.textContent!, original);
    const visibleText = normalize(await page.locator("article").textContent() ?? "");
    if (name) expect(visibleText).toBe(normalize(sourceText)); else expect(visibleText).toContain(normalize(sourceText));
    await page.screenshot({ path: `test-results/public-${name || "home"}-${width}.png`, fullPage: true });
    // Check lower sections as well as the initial viewport on long legal pages.
    await page.locator(".site-footer").scrollIntoViewIfNeeded();
    await expect(page.locator(".site-footer")).toBeVisible();
    await page.screenshot({ path: `test-results/public-${name || "home"}-${width}-bottom.png` });
    await page.reload(); await expect(page.locator("h1")).toBeVisible();
  }
  const mail = page.locator('a[href^="mailto:"]');
  if (["support","delete-account","privacy","privacy-choices"].includes(name)) expect(await mail.count()).toBeGreaterThan(0);
  await page.keyboard.press("Tab"); await expect(page.locator(".skip-link")).toBeFocused();
  expect(await page.locator(".skip-link").evaluate((el) => getComputedStyle(el).outlineStyle)).toBe("solid");
  expect(errors).toEqual([]);
});

test("Pages rules isolate public pages, SPA routes, missing assets and verification files", async ({ request }) => {
  for (const route of ["/app/", "/app/login", "/app/auth/callback", "/app/auth/reset", "/app/legal/privacy", "/app/legal/terms"]) {
    const response = await request.get(route, { maxRedirects: 0 }); expect(response.status()).toBe(200);
    expect(await response.text()).toContain('id="root"');
    expect(await response.text()).toMatch(/src="\/app\/assets\//);
  }
  for (const route of ["/missing-page", "/missing.js", "/app/assets/missing.js", "/app/brand-missing.png", "/app/missing-page", "/.well-known/missing.json", "/privacy/missing.js"]) {
    const response = await request.get(route); expect(response.status(), route).toBe(404); expect(await response.text()).not.toContain('id="root"');
  }
  for (const file of ["apple-app-site-association", "assetlinks.json"]) {
    const response = await request.get(`/.well-known/${file}`, { maxRedirects: 0 });
    expect(response.status()).toBe(200); expect(response.headers()["content-type"]).toContain("application/json");
    expect(await response.body()).toEqual(await readFile(new URL(`../site/source/.well-known/${file}`, import.meta.url)));
  }
  for (const file of ["/style.css", "/site-assets/brand.png", "/app/brand.png", "/app/google.png", "/app/apple.svg"]) expect((await request.get(file)).status(), file).toBe(200);
  const old = await request.get("/auth/callback?code=synthetic-only", { maxRedirects: 0 });
  expect(old.status()).toBe(302); expect(old.headers().location).toContain("/app/auth/callback?code=synthetic-only");
  const reset = await request.get("/auth/reset?type=recovery", { maxRedirects: 0 }); expect(reset.headers().location).toContain("/app/auth/reset?type=recovery");
});

for (const platform of ["desktop","ios","android","ipad"]) test(`invitation platform detection: ${platform}`, async ({ browser }) => {
  const context = await browser.newContext({ baseURL: "http://127.0.0.1:4173", userAgent: platform === "ios" ? "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)" : platform === "android" ? "Mozilla/5.0 (Linux; Android 15)" : "Mozilla/5.0 (Macintosh; Intel Mac OS X)" });
  if (platform === "ipad") await context.addInitScript(() => { Object.defineProperty(navigator,"platform",{get:()=>"MacIntel"}); Object.defineProperty(navigator,"maxTouchPoints",{get:()=>5}); });
  const page = await context.newPage();
  await page.route("**/*", (route) => new URL(route.request().url()).hostname === "127.0.0.1" ? route.continue() : route.abort());
  await page.goto("/invite/synthetic-invitation-token?source=synthetic");
  await expect(page.locator("h1")).toHaveText("הוזמנת ל-CBTipul");
  await expect(page.locator("#ios-store")).toHaveAttribute("href", "https://apps.apple.com/il/app/cbtipul/id6809343831?l=he");
  await expect(page.locator("#android-store")).toHaveAttribute("href", "https://play.google.com/store/apps/details?id=com.CBTipul.app");
  if (platform === "ios" || platform === "ipad") { await expect(page.locator("#ios-store")).toBeVisible(); await expect(page.locator("#android-store")).toBeHidden(); }
  else if (platform === "android") { await expect(page.locator("#android-store")).toBeVisible(); await expect(page.locator("#ios-store")).toBeHidden(); }
  else { await expect(page.locator("#ios-store")).toBeVisible(); await expect(page.locator("#android-store")).toBeVisible(); }
  expect(await page.locator("body").textContent()).not.toContain("synthetic-invitation-token");
  expect(await page.evaluate(() => JSON.stringify(localStorage) + JSON.stringify(sessionStorage))).not.toContain("synthetic-invitation-token");
  await page.reload(); await expect(page.locator("h1")).toHaveText("הוזמנת ל-CBTipul"); await context.close();
});

test("workspace refresh, prefixed assets and password-reset page", async ({ page }) => {
  await page.route("**/*", (route) => new URL(route.request().url()).hostname === "127.0.0.1" ? route.continue() : route.abort());
  await page.goto("/app/"); await expect(page).toHaveURL(/\/app\/login$/); await page.reload();
  await expect(page.locator(".auth-page")).toBeVisible();
  await expect(page.locator('.auth-story img')).toHaveAttribute("src", "/app/brand.png");
  await page.goto("/app/auth/reset"); await expect(page).toHaveURL(/\/app\/auth\/reset$/); await expect(page.locator(".auth-page")).toBeVisible(); await page.reload(); await expect(page.locator(".auth-page")).toBeVisible();
  await page.screenshot({ path:"test-results/app-password-reset.png" });
});
for (const provider of ["google","apple"]) test(`browser ${provider} OAuth uses /app/ callback`, async ({ page }) => {
  let target = "";
  await page.route("**/*", async (route) => {
    const url = new URL(route.request().url()); if (url.hostname === "127.0.0.1") return route.continue();
    if (url.pathname.endsWith("/authorize")) { target = url.searchParams.get("redirect_to") ?? ""; return route.fulfill({ contentType:"text/html", body:"Mock provider redirect intercepted" }); }
    return route.abort();
  });
  await page.goto("/app/login"); await page.getByRole("button", { name: provider === "google" ? "כניסה באמצעות Google" : "כניסה באמצעות Apple" }).click();
  await expect.poll(() => target).toBe("http://127.0.0.1:4173/app/auth/callback");
});
