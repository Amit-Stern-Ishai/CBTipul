import { createWorksheet, type WorksheetType, type WorkspacePayload } from "../src/workspace/model";
import { test, expect, type Page } from "@playwright/test";

const user = { id: "therapist-fixture", email: "fixture@example.invalid", is_anonymous: false, app_metadata: { provider: "email" }, user_metadata: {}, aud: "authenticated", created_at: "2026-01-01T00:00:00Z" };
const runtimeErrors = new WeakMap<Page, string[]>();
test.beforeEach(({ page }) => {
  const errors: string[] = []; runtimeErrors.set(page, errors);
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => { if (message.type() === "error" && /Encountered two children|React has detected/.test(message.text())) errors.push(message.text()); });
});
test.afterEach(({ page }) => { expect(runtimeErrors.get(page)).toEqual([]); });
const empty = { version: 1, items: [], notes: "" };
async function fixture(page: Page, options: { existing?: boolean; locked?: boolean; access?: string; consent?: boolean; anonymizeFail?: boolean; payload?: WorkspacePayload; beforeSave?: () => Promise<string | undefined> } = {}) {
  let envelope = { id: "workspace-fixture", status: "active", started_at: new Date(Date.now() - 15 * 60_000).toISOString(), updated_at: new Date().toISOString(), revision: 0, payload: options.payload ?? (options.existing ? { ...empty, notes: "תוכן קליני סינתטי" } : empty), lease_token: "lease-fixture", lease_until: new Date(Date.now() + 120_000).toISOString() };
  let locked = !!options.locked;
  let started = !!options.existing;
  const requests: { path: string; body: Record<string, unknown> | null }[] = [];
  await page.route("**/*", async (route) => {
    const url = new URL(route.request().url());
    if (url.hostname === "127.0.0.1") return route.continue();
    if (url.hostname !== "fixture.supabase.invalid") return route.abort();
    const path = url.pathname;
    const method = route.request().method();
    const body = method === "POST" ? route.request().postDataJSON() as Record<string, unknown> : null;
    if (method === "OPTIONS") return route.fulfill({ status: 200, headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "*" } });
    requests.push({ path, body });
    let data: unknown;
    let status = 200;
    if (path.endsWith("/user")) data = user;
    else if (path.endsWith("/token")) data = { access_token: "fixture-token", refresh_token: "fixture-refresh", expires_in: 3600, token_type: "bearer", user };
    else if (path.endsWith("/logout")) data = {};
    else if (path.endsWith("/get-app-context")) data = { version: 1, role: "therapist", entitlement: { access: options.access ?? "full" } };
    else if (path.endsWith("/anonymize-clinical-text")) {
      if (options.anonymizeFail) { status = 500; data = { error: "failed" }; }
      else data = { anonymizedText: `אנונימי: ${body?.text}` };
    }
    else if (path.endsWith("/get_active_web_workspace")) data = started && envelope.status === "active" ? envelope : null;
    else if (path.endsWith("/begin_web_workspace")) {
      if (locked && !body?.p_take_over) { status = 400; data = { message: "workspace_in_use" }; }
      else { locked = false; started = true; data = envelope; }
    }
    else if (path.endsWith("/renew_web_workspace_lease")) data = new Date(Date.now() + 120_000).toISOString();
    else if (path.endsWith("/save_web_workspace")) {
      const error = await options.beforeSave?.();
      if (error) { status = 400; data = { message: error }; }
      else if (body?.p_expected_revision !== envelope.revision) { status = 400; data = { message: "revision_conflict" }; }
      else { envelope = { ...envelope, revision: envelope.revision + 1, payload: body.p_payload as typeof empty }; data = { id: envelope.id, revision: envelope.revision, saved_at: new Date().toISOString() }; }
    }
    else if (path.endsWith("/finish_web_workspace")) { envelope = { ...envelope, status: "pending" }; data = { id: envelope.id, status: "pending", notification_id: "notification-fixture" }; }
    else if (path.endsWith("/discard_web_workspace")) { envelope = { ...envelope, status: "discarded" }; data = null; }
    else throw new Error(`Unexpected endpoint: ${path}`);
    await route.fulfill({ status, contentType: "application/json", headers: { "access-control-allow-origin": "*" }, body: JSON.stringify(data) });
  });
  await page.addInitScript(({ account, consent }) => {
    if (sessionStorage.getItem("fixture-seeded")) return;
    sessionStorage.setItem("fixture-seeded", "yes");
    localStorage.setItem("cbtipul.web.auth", JSON.stringify({ access_token: "fixture-token", refresh_token: "fixture-refresh", expires_at: Math.floor(Date.now() / 1000) + 3600, token_type: "bearer", user: account }));
    localStorage.setItem(`cbtipul.terms.${account.id}`, "2026-08-29");
    if (consent) localStorage.setItem(`cbtipul.ai.${account.id}`, "yes");
  }, { account: user, consent: options.consent !== false });
  return requests;
}

test("desktop flow saves one workspace, clears content on finish, and never fetches patient records", async ({ page }) => {
  const requests = await fixture(page);
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "מרחב המפגש" })).toBeVisible();
  await page.getByRole("button", { name: "התחלת מפגש", exact: true }).click();
  await page.getByLabel("סיכום המפגש", { exact: true }).fill("סיכום סינתטי למפגש");
  await expect(page.getByText("כל השינויים נשמרו")).toBeVisible();
  const save = requests.find((r) => r.path.endsWith("/save_web_workspace"));
  expect((save?.body?.p_payload as typeof empty).notes).toBe("אנונימי: סיכום סינתטי למפגש");
  await expect(page.getByLabel("סיכום המפגש", { exact: true })).toHaveValue("סיכום סינתטי למפגש");
  expect(await page.evaluate(() => JSON.stringify(sessionStorage) + JSON.stringify(localStorage))).not.toContain("סיכום סינתטי למפגש");
  await page.screenshot({ path: "test-results/workspace-desktop.png", fullPage: true });
  await page.getByRole("button", { name: "סיום ושמירה", exact: true }).first().click();
  await page.getByLabel("קוד התייחסות (לא חובה)").fill("REF-01");
  await page.getByRole("button", { name: "סיום ושמירה", exact: true }).last().click();
  await expect(page.getByRole("heading", { name: "המפגש נשמר" })).toBeVisible();
  await expect(page.getByText("סיכום סינתטי למפגש")).toHaveCount(0);
  expect(requests.filter((r) => r.path.includes("/rest/v1/")).map((r) => r.path)).toEqual(expect.arrayContaining([expect.stringContaining("get_active_web_workspace"), expect.stringContaining("save_web_workspace"), expect.stringContaining("finish_web_workspace")]));
  expect(requests.some((r) => /Patients|CombinedMood|Sessions|notifications|list_pending|associate_web_workspace/.test(r.path))).toBe(false);
  const finish = requests.find((r) => r.path.endsWith("finish_web_workspace"));
  expect(finish?.body?.p_reference_label).toBe("REF-01");
  await page.screenshot({ path: "test-results/workspace-success.png", fullPage: true });
});

test("resume starts neutral; another editor requires explicit takeover", async ({ page }) => {
  const requests = await fixture(page, { existing: true, locked: true });
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "יש מפגש פתוח" })).toBeVisible();
  await expect(page.getByText("תוכן קליני סינתטי")).toHaveCount(0);
  await page.getByRole("button", { name: "המשך המפגש" }).click();
  await expect(page.getByRole("heading", { name: "המפגש פתוח במקום אחר" })).toBeVisible();
  await page.getByRole("button", { name: "העברת השליטה לכאן" }).click();
  await expect(page.getByLabel("סיכום המפגש", { exact: true })).toHaveValue("תוכן קליני סינתטי");
  expect(requests.filter((r) => r.path.endsWith("begin_web_workspace")).map((r) => r.body?.p_take_over)).toEqual([false, true]);
});

test("incomplete included diary blocks finishing until explicitly removed", async ({ page }) => {
  await fixture(page);
  await page.goto("/");
  await page.getByRole("button", { name: "התחלת מפגש", exact: true }).click();
  await page.getByRole("button", { name: "הוספת טופס" }).click();
  await page.getByRole("button", { name: "הוספת יומן מחשבות 3" }).click();
  await expect(page.getByText("יש לסמן טעות חשיבה שזוהתה או לאשר שלא זוהתה טעות חשיבה.")).toBeVisible();
  await expect(page.getByLabel("לא זוהתה טעות חשיבה")).not.toBeChecked();
  await page.getByLabel("לא זוהתה טעות חשיבה").check();
  await expect(page.getByLabel("לא זוהתה טעות חשיבה")).toBeChecked();
  await page.getByRole("button", { name: "סיום ושמירה", exact: true }).first().click();
  await expect(page.getByText("כדי לסיים, יש להשלים את הטפסים המסומנים או להסיר אותם במפורש.").first()).toBeVisible();
  page.once("dialog", (dialog) => dialog.accept());
  await page.getByRole("button", { name: "הסרת הטופס" }).click();
  await page.getByRole("button", { name: "סיכום המפגש" }).click();
  await page.getByLabel("סיכום המפגש", { exact: true }).fill("סיכום סינתטי");
  await page.getByRole("button", { name: "סיום ושמירה", exact: true }).first().click();
  await expect(page.getByRole("heading", { name: "אישור סיום ושמירה" })).toBeVisible();
});

test("narrow workspace remains usable and public legal route stays available", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await fixture(page);
  await page.goto("/");
  await page.getByRole("button", { name: "התחלת מפגש", exact: true }).click();
  await page.getByRole("button", { name: "הוספת טופס" }).click();
  await page.getByRole("button", { name: "הוספת שאלון" }).click();
  await expect(page.getByRole("heading", { name: "שאלון GAD-7 + PHQ-9" })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)).toBe(true);
  await page.screenshot({ path: "test-results/workspace-mobile.png", fullPage: true });
  await page.getByRole("button", { name: "מחיקת טיוטה" }).click();
  await expect(page.getByRole("region", { name: "אישור מחיקת הטיוטה" })).toBeVisible();
  expect(await page.evaluate(() => document.activeElement?.getAttribute("aria-label"))).toBe("אישור מחיקת הטיוטה");
  await page.goto("/legal/privacy");
  await expect(page.getByRole("heading", { name: "מדיניות פרטיות" })).toBeVisible();
});

test("clinical text needs consent, then the saved anonymized snapshot appears after reopening", async ({ page }) => {
  const requests = await fixture(page, { consent: false });
  await page.goto("/");
  await page.getByRole("button", { name: "התחלת מפגש", exact: true }).click();
  await page.getByLabel("סיכום המפגש", { exact: true }).fill("נוסח מקורי סינתטי");
  await expect(page.getByRole("heading", { name: "אישור לעיבוד טקסט קליני" })).toBeVisible();
  expect(requests.filter((request) => request.path.endsWith("/save_web_workspace"))).toHaveLength(0);
  await page.getByRole("button", { name: "אני מאשר/ת את העיבוד והשמירה" }).click();
  await expect(page.getByText("כל השינויים נשמרו")).toBeVisible();
  expect(requests.filter((request) => request.path.endsWith("/anonymize-clinical-text"))).toHaveLength(1);
  expect((requests.find((request) => request.path.endsWith("/save_web_workspace"))?.body?.p_payload as typeof empty).notes).toBe("אנונימי: נוסח מקורי סינתטי");
  await expect(page.getByLabel("סיכום המפגש", { exact: true })).toHaveValue("נוסח מקורי סינתטי");
  await page.reload();
  await expect(page.getByRole("heading", { name: "יש מפגש פתוח" })).toBeVisible();
  await page.getByRole("button", { name: "המשך המפגש" }).click();
  await expect(page.getByLabel("סיכום המפגש", { exact: true })).toHaveValue("אנונימי: נוסח מקורי סינתטי");
});

test("anonymization failure leaves original text in the open tab and never calls save", async ({ page }) => {
  const requests = await fixture(page, { anonymizeFail: true });
  await page.goto("/");
  await page.getByRole("button", { name: "התחלת מפגש", exact: true }).click();
  await page.getByLabel("סיכום המפגש", { exact: true }).fill("נוסח מקורי סינתטי");
  await expect(page.getByText("השינויים טרם נשמרו. אפשר לנסות שוב.")).toBeVisible();
  await expect(page.getByLabel("סיכום המפגש", { exact: true })).toHaveValue("נוסח מקורי סינתטי");
  expect(requests.filter((request) => request.path.endsWith("/save_web_workspace"))).toHaveLength(0);
  expect(await page.evaluate(() => JSON.stringify(sessionStorage) + JSON.stringify(localStorage))).not.toContain("נוסח מקורי סינתטי");
});


function diaryPayload(type: WorksheetType): WorkspacePayload {
  const item = createWorksheet(type);
  item.data = type === "diary_three" ? { situation: 'אמא אמרה: "לא!"', automatic_thoughts: [{ text: "אבא ואני…", beliefBefore: 80, beliefAfter: 20 }], feelings: [{ name: "עצבות", intensityBefore: 80, intensityAfter: 20 }], thinking_errors: [], alternative_thoughts: [{ text: "אפשר גם אחרת", belief: 50 }] } : { event: 'אמא אמרה: "לא!"', automatic_thoughts: ["אבא ואני…"], feelings: [{ name: "עצבות", intensity: 60 }], ...(type === "diary_one" ? { behaviour: "נשארתי", physical_symptoms: "" } : { thinking_errors: [], alternative_thoughts: ["אפשר גם אחרת"] }) };
  return { version: 1, notes: "", items: [item] };
}
for (const type of ["diary_one", "diary_two", "diary_three"] as const) {
  test(`${type} save waits for ACK, preserves original text and stays editable`, async ({ page }) => {
    let release!: () => void; const gate = new Promise<void>((r) => { release = r; });
    const original = diaryPayload(type);
    const requests = await fixture(page, { existing: true, payload: original, consent: false, beforeSave: async () => { await gate; return undefined; } });
    await page.goto("/"); await page.getByRole("button", { name: "המשך המפגש", exact: true }).click();
    await page.locator(".ww-item").first().click();
    await page.getByRole("button", { name: "שמירת הרשומה", exact: true }).click();
    const saving = page.getByRole("button", { name: "שומר…", exact: true }); await expect(saving).toBeDisabled(); await expect(saving).toHaveAttribute("aria-busy", "true");
    await expect(page.getByText("הרשומה נשמרה", { exact: true })).toHaveCount(0);
    await expect.poll(() => requests.filter((r) => r.path.endsWith("/save_web_workspace")).length).toBe(1);
    await page.locator(".ww-item").last().click(); await page.locator(".ww-item").first().click();
    await expect(saving).toBeDisabled();
    release(); await expect(page.getByText("הרשומה נשמרה", { exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "שמירת הרשומה", exact: true })).toBeEnabled();
    expect((requests.find((r) => r.path.endsWith("/save_web_workspace"))?.body?.p_payload as WorkspacePayload).items[0].data).toEqual(original.items[0].data);
    expect(requests.some((r) => r.path.endsWith("/anonymize-clinical-text"))).toBe(false);
    await expect(page.locator(".ww-sheet textarea").first()).toBeEnabled();
    await page.locator(".ww-sheet textarea").first().fill("עדכון נוסף");
    await expect(page.getByText("הגרסה שנשלחה נשמרה. יש שינויים חדשים שטרם אושרו בשמירה.")).toBeVisible();
    expect(requests.some((r) => r.path.endsWith("/finish_web_workspace"))).toBe(false);
    await page.screenshot({ path: `test-results/${type}-desktop.png`, fullPage: true });
    await page.setViewportSize({ width: 390, height: 900 });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    await page.screenshot({ path: `test-results/${type}-narrow.png` });
  });
  for (const error of ["network", "lease_lost"]) test(`${type} button recovers after ${error}`, async ({ page }) => {
    let fail = true;
    await fixture(page, { existing: true, payload: diaryPayload(type), beforeSave: async () => fail ? error : undefined });
    await page.goto("/"); await page.getByRole("button", { name: "המשך המפגש", exact: true }).click(); await page.locator(".ww-item").first().click();
    await page.getByRole("button", { name: "שמירת הרשומה", exact: true }).click();
    await expect(page.getByText("הרשומה לא נשמרה", { exact: true })).toBeVisible();
    await expect(page.locator('.ww-form-end button')).toHaveAttribute("aria-busy", "false");
    await expect(page.locator(".ww-sheet textarea").first()).toHaveValue('אמא אמרה: "לא!"');
    if (error === "network") { fail = false; await page.locator('.ww-form-end button').click(); await expect(page.getByText("הרשומה נשמרה", { exact: true })).toBeVisible(); }
  });
}
test("mobile scores and branding at desktop and narrow widths", async ({ page }) => {
  const item = createWorksheet("questionnaire");
  await fixture(page, { existing: true, payload: { version: 1, notes: "", items: [item] } });
  await page.goto("/"); await page.screenshot({ path: "test-results/branded-resume.png", fullPage: true });
  await page.getByRole("button", { name: "המשך המפגש", exact: true }).click(); await page.locator(".ww-item").first().click();
  await expect(page.getByText("0 מתוך 7 תשובות · השאלון טרם הושלם")).toBeVisible();
  for (let i = 0; i < 7; i++) await page.locator(`input[name="${item.id}-0-${i}"]`).nth(1).check();
  for (let i = 0; i < 9; i++) await page.locator(`input[name="${item.id}-1-${i}"]`).nth(2).check();
  await expect(page.getByText("חרדה קלה", { exact: true })).toBeVisible(); await expect(page.getByText("דיכאון בינוני כבד", { exact: true })).toBeVisible();
  await expect(page.locator(".ww-scores")).toContainText("7"); await expect(page.locator(".ww-scores")).toContainText("18");
  await expect(page.locator(".ww-safety").first()).toBeVisible();
  for (const width of [1440,390]) {
    await page.setViewportSize({ width, height: 1000 });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    expect(await page.locator(".ww-app").evaluate((el) => getComputedStyle(el).backgroundColor)).toBe("rgb(241, 244, 248)");
    await page.screenshot({ path: `test-results/branded-scores-${width}.png`, fullPage: true });
  }
});
test("branded login at desktop and narrow widths", async ({ page }) => {
  await page.route("**/*", (route) => new URL(route.request().url()).hostname === "127.0.0.1" ? route.continue() : route.abort());
  await page.goto("/login");
  for (const width of [1440,390]) {
    await page.setViewportSize({ width, height: 1000 });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    await expect(page.locator('img[alt="CBTipul"]:visible')).toBeVisible();
    await page.screenshot({ path: `test-results/branded-login-${width}.png`, fullPage: true });
  }
});
