import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { composeSite, webRoot, pages, redirects } from "./compose-site.mjs";
test("compiled public pages preserve original content, invitation behavior and verification bytes", async () => {
  const out = await mkdtemp(path.join(tmpdir(), "cbtipul-site-"));
  try {
    await composeSite(out);
    const manifest = JSON.parse(await readFile(path.join(webRoot, "site/source-manifest.json"), "utf8"));
    for (const [name, hash] of Object.entries(manifest)) assert.equal(createHash("sha256").update(await readFile(path.join(webRoot, "site/source", name))).digest("hex"), hash);
    for (const page of pages) {
      const original = await readFile(path.join(webRoot, "site/source", page, "index.html"), "utf8");
      const html = await readFile(path.join(out, page, "index.html"), "utf8");
      const body = original.match(/<article[^>]*>([\s\S]*?)<\/article>/)[1];
      assert.ok(html.includes(body), `Original article preserved for ${page || "home"}`);
      for (const match of original.matchAll(/<script>([\s\S]*?)<\/script>/g)) assert.ok(html.includes(match[0]));
      assert.ok(html.includes('href="/app/">כניסה למטפלים'));
      assert.ok(html.includes('lang="he" dir="rtl"'));
    }
    for (const name of ["apple-app-site-association", "assetlinks.json"]) assert.deepEqual(await readFile(path.join(out, ".well-known", name)), await readFile(path.join(webRoot, "site/source/.well-known", name)));
    assert.ok((await readFile(path.join(out, "404.html"), "utf8")).includes("העמוד לא נמצא"));
    assert.ok(!redirects.includes("/app/*")); assert.ok(!redirects.includes("/* /index.html"));
    const headers = await readFile(path.join(out, "_headers"), "utf8"); assert.ok(headers.includes("Content-Type: application/json"));
    assert.ok(headers.includes("script-src 'self' 'sha256-")); assert.ok(headers.includes("/app/*"));
  } finally { await rm(out, { recursive:true, force:true }); }
});
