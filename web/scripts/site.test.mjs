import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { composeSite, webRoot, pages, redirects, escapeHtml } from "./compose-site.mjs";
test("compiled public pages preserve original content, invitation behavior and verification bytes", async () => {
  const out = await mkdtemp(path.join(tmpdir(), "cbtipul-site-"));
  try {
    await composeSite(out, {script:"/app/assets/public-site-fixture.js",styles:["/app/assets/chrome-fixture.css"]});
    const manifest = JSON.parse(await readFile(path.join(webRoot, "site/source-manifest.json"), "utf8"));
    for (const [name, hash] of Object.entries(manifest)) assert.equal(createHash("sha256").update(await readFile(path.join(webRoot, "site/source", name))).digest("hex"), hash);
    for (const page of pages) {
      const original = await readFile(path.join(webRoot, "site/source", page, "index.html"), "utf8");
      const html = await readFile(path.join(out, page, "index.html"), "utf8");
      const body = original.match(/<article[^>]*>([\s\S]*?)<\/article>/)[1];
      const legal = JSON.parse(await readFile(path.join(webRoot, "src/legal-he.json"), "utf8"));
      if (["terms", "privacy"].includes(page)) assert.ok(html.includes(`<div class="canonical-legal">${escapeHtml(legal[page === "terms" ? "termsBody" : "privacyBody"])}</div>`));
      else assert.ok(html.includes(body), `Original article preserved for ${page || "home"}`);
      for (const match of original.matchAll(/<script>([\s\S]*?)<\/script>/g)) assert.ok(html.includes(match[0]));
      assert.ok(html.includes('href="/app/">כניסה למטפלים'));
      assert.ok(html.includes('lang="he" dir="rtl"'));
      const themeUrl = html.match(/href="(\/site-assets\/theme-[a-f0-9]{12}\.css)"/)[1];
      assert.deepEqual(await readFile(path.join(out, themeUrl)), await readFile(path.join(webRoot, "site/theme.css")));
      assert.ok(!html.includes('href="/style.css"'));
      assert.ok(html.includes('width="40" height="40"'));
    }
    for (const name of ["apple-app-site-association", "assetlinks.json"]) assert.deepEqual(await readFile(path.join(out, ".well-known", name)), await readFile(path.join(webRoot, "site/source/.well-known", name)));
    assert.ok((await readFile(path.join(out, "404.html"), "utf8")).includes("העמוד לא נמצא"));
    assert.ok(!redirects.includes("/app/*")); assert.ok(!redirects.includes("/* /index.html"));
    const headers = await readFile(path.join(out, "_headers"), "utf8"); assert.ok(headers.includes("Content-Type: application/json"));
    assert.ok(headers.includes("script-src 'self' 'sha256-")); assert.ok(headers.includes("/app/*"));
  } finally { await rm(out, { recursive:true, force:true }); }
});

test("selected legal bodies and acceptance assembly retain rollout hashes", async () => {
  const legal = JSON.parse(await readFile(path.join(webRoot, "src/legal-he.json"), "utf8"));
  const he = await readFile(path.join(webRoot, "src/he.ts"), "utf8");
  const ww = await readFile(path.join(webRoot, "src/workspace/he.ts"), "utf8");
  const value = (source, key) => JSON.parse(source.match(new RegExp(`\\b${key}:\\s*("(?:[^"\\\\]|\\\\.)*")`))[1]);
  const hash = text => createHash("sha256").update(text).digest("hex");
  assert.equal(hash(legal.termsBody), "3ff17c4f9066d89c04a2a5c6f7caa9d24f497e969608cd7e7879869a8a11faa6");
  assert.equal(hash(legal.privacyBody), "3c87e0f72db38ad6269c0d1728eeb3228bbbf6a2647a69814893bd423f19fa1d");
  const terms = [value(he,"App001"),value(he,"App002"),value(he,"Login024"),legal.termsBody,value(he,"Login025"),legal.privacyBody,value(he,"App003"),value(he,"Profile001")].join("\n\n");
  const clinical = [value(ww,"consentTitle"),value(ww,"consentDescription"),value(ww,"consentAction"),value(he,"consentDecline")].join("\n\n");
  assert.equal(hash(terms), "4a70ebd14e053a469bc7460fb4e77629aed0b35c02f5fb5cc451956d078fea02");
  assert.equal(hash(clinical), "aba24ae3cc73d8498b2f1f6a120872efb8c9ffefa8338ea3b3d7429724dc0799");
});
