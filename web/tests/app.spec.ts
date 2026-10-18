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
async function fixture(page: Page, options: { existing?: boolean; locked?: boolean; access?: string; consent?: boolean; terms?: boolean; oldTermsVersion?: boolean; lookupFail?: boolean; persistFail?: boolean; loseConsentResponse?: boolean; consentInterveningRevocation?: boolean; account?: typeof user; anonymizeFail?: boolean; payload?: WorkspacePayload; beforeSave?: () => Promise<string | undefined> } = {}) {
  let envelope = { id: "workspace-fixture", status: "active", started_at: new Date(Date.now() - 15 * 60_000).toISOString(), updated_at: new Date().toISOString(), revision: 0, payload: options.payload ?? (options.existing ? { ...empty, notes: "תוכן קליני סינתטי" } : empty), lease_token: "lease-fixture", lease_until: new Date(Date.now() + 120_000).toISOString() };
  const decisions = new Map<string, { status: string; revision: number }>();
  const consentRequests = new Map<string, { args: string; receipt: unknown; revision: number }>();
  let locked = !!options.locked;
  let started = !!options.existing;
  const requests: { path: string; body: Record<string, unknown> | null }[] = [];
  await page.route("**/*", async (route) => {
    const url = new URL(route.request().url());
    if (url.hostname === "127.0.0.1") return route.continue();
    if (url.hostname !== "fixture-cbtipul.supabase.co") return route.abort();
    const path = url.pathname;
    const method = route.request().method();
    const body = method === "POST" ? route.request().postDataJSON() as Record<string, unknown> : null;
    if (method === "OPTIONS") return route.fulfill({ status: 200, headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "*" } });
    requests.push({ path, body });
    let data: unknown;
    let status = 200;
    if (path.endsWith("/user")) data = options.account ?? user;
    else if (path.endsWith("/token")) data = { access_token: "fixture-token", refresh_token: "fixture-refresh", expires_in: 3600, token_type: "bearer", user };
    else if (path.endsWith("/logout")) data = {};
    else if (path.endsWith("/therapist_profiles")) data = [{ therapist_id: (options.account ?? user).id, display_name: "ד״ר מטפל לדוגמה" }];
    else if (path.endsWith("/get-app-context")) data = { version: 1, role: "therapist", entitlement: { access: options.access ?? "full" } };
    else if (path.endsWith("/get_my_consent") || path.endsWith("/record_my_consent")) {
      const type=String(body?.p_consent_type), account=(options.account??user).id, key=`${account}:${type}`;
      const accepted=type === "terms_privacy" ? options.terms !== false : options.consent !== false;
      let current=decisions.get(key)??{status:accepted?"accepted":"required",revision:accepted?1:0};
      const write=path.endsWith("/record_my_consent"), requestKey=`${account}:${body?.p_request_id}`, prior=consentRequests.get(requestKey);
      let error="";
      if(write) {
        expect(Object.keys(body!).sort()).toEqual(["p_consent_type","p_required_version","p_decision","p_request_id","p_expected_revision"].sort());
        if(prior && prior.args!==JSON.stringify(body)) error="consent_request_id_reused";
        else if(prior && prior.revision!==current.revision) error="consent_request_superseded";
        else if(!prior && body?.p_expected_revision!==current.revision) error="consent_revision_conflict";
        else if(!prior && !options.persistFail) {
          current={status:String(body?.p_decision),revision:current.revision+(current.status===body?.p_decision?0:1)};
          decisions.set(key,current);
        }
      }
      data={therapist_id:account,consent_type:type,required_version:body?.p_required_version,accepted_version:current.status==="accepted"?body?.p_required_version:null,accepted_at:current.status==="accepted"?"2026-10-15T10:00:00Z":null,revoked_at:current.status==="revoked"?"2026-10-15T11:00:00Z":null,status:current.status,revision:current.revision};
      if(options.oldTermsVersion && type === "terms_privacy" && current.status === "required") {
        data={...(data as Record<string,unknown>),accepted_version:"previous-wording-version",accepted_at:"2026-08-01T10:00:00Z"};
      }
      if(error) {status=400;data={code:"P0001",message:error};}
      else if(options.lookupFail && !write || options.persistFail && write) {status=503;data={message:"unavailable"};}
      else if(prior && write) data=prior.receipt;
      else if(write) {
        consentRequests.set(requestKey,{args:JSON.stringify(body),receipt:data,revision:current.revision});
        if(options.loseConsentResponse) {
          options.loseConsentResponse=false;
          if(options.consentInterveningRevocation) decisions.set(key,{status:"revoked",revision:current.revision+1});
          return route.abort("failed");
        }
      }
    }
    else if (path.endsWith("/anonymize-clinical-text")) {
      if (options.anonymizeFail) { status = 500; data = { error: "failed" }; }
      else data = { anonymizedText: `אנונימי: ${body?.text}` };
    }
    else if (path.endsWith("/get_active_web_workspace")) data = started && envelope.status === "active" ? envelope : null;
    else if (path.endsWith("/begin_web_workspace")) {
      if (locked && !body?.p_take_over) { status = 400; data = { message: "workspace_in_use" }; }
      else { locked = false; started = true; if(envelope.status !== "active") envelope={...envelope,id:"workspace-fixture-next",status:"active",revision:0,payload:empty}; data = envelope; }
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
  await page.goto("/app/");
  await expect(page.getByRole("heading", { name: "מרחב העבודה למטפלים" })).toBeVisible();
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
  await page.goto("/app/");
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
  await page.goto("/app/");
  await page.getByRole("button", { name: "התחלת מפגש", exact: true }).click();
  await page.getByRole("button", { name: "הוספת פעילות" }).click();
  await page.getByRole("button", { name: "הוספת יומן מחשבות 3" }).click();
  await expect(page.getByText("יש לסמן טעות חשיבה שזוהתה או לאשר שלא זוהתה טעות חשיבה.")).toBeVisible();
  await expect(page.getByLabel("לא זוהתה טעות חשיבה")).not.toBeChecked();
  await page.getByLabel("לא זוהתה טעות חשיבה").check();
  await expect(page.getByLabel("לא זוהתה טעות חשיבה")).toBeChecked();
  await page.getByRole("button", { name: "סיום ושמירה", exact: true }).first().click();
  await expect(page.getByText("כדי לסיים, יש להשלים את הפעילויות המסומנות או להסיר אותן במפורש.").first()).toBeVisible();
  page.once("dialog", (dialog) => dialog.accept());
  await page.getByRole("button", { name: "הסרת הפעילות" }).click();
  await page.getByRole("button", { name: "סיכום המפגש" }).click();
  await page.getByLabel("סיכום המפגש", { exact: true }).fill("סיכום סינתטי");
  await page.getByRole("button", { name: "סיום ושמירה", exact: true }).first().click();
  await expect(page.getByRole("heading", { name: "אישור סיום ושמירה" })).toBeVisible();
});

test("narrow workspace remains usable and public legal route stays available", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await fixture(page);
  await page.goto("/app/");
  await page.getByRole("button", { name: "התחלת מפגש", exact: true }).click();
  await page.getByRole("button", { name: "הוספת פעילות" }).click();
  await page.getByRole("button", { name: "הוספת שאלון" }).click();
  await expect(page.getByRole("heading", { name: "שאלון GAD-7 + PHQ-9" })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)).toBe(true);
  await page.screenshot({ path: "test-results/workspace-mobile.png", fullPage: true });
  await page.getByRole("button", { name: "מחיקת טיוטה" }).click();
  await expect(page.getByRole("region", { name: "אישור מחיקת הטיוטה" })).toBeVisible();
  expect(await page.evaluate(() => document.activeElement?.getAttribute("aria-label"))).toBe("אישור מחיקת הטיוטה");
  await page.goto("/app/legal/privacy");
  await expect(page.getByRole("heading", { name: "מדיניות פרטיות" })).toBeVisible();
});

test("clinical text needs consent, then the saved anonymized snapshot appears after reopening", async ({ page }) => {
  const requests = await fixture(page, { consent: false });
  await page.goto("/app/");
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
  await page.goto("/app/");
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
    await page.setViewportSize({width:1366,height:768});
    const original = diaryPayload(type);
    const requests = await fixture(page, { existing: true, payload: original, consent: false, beforeSave: async () => { await gate; return undefined; } });
    await page.goto("/app/"); await page.getByRole("button", { name: "המשך המפגש", exact: true }).click();
    await page.locator(".ww-item").first().click();
    await page.getByRole("button", { name: "שמירת הרשומה", exact: true }).click();
    const saving = page.getByRole("button", { name: "שומר…", exact: true }); await expect(saving).toBeDisabled(); await expect(saving).toHaveAttribute("aria-busy", "true");
    await expect(page.getByText("הרשומה נשמרה", { exact: true })).toHaveCount(0);
    await page.screenshot({path:`test-results/${type}-saving.png`,fullPage:true});
    await expect.poll(() => requests.filter((r) => r.path.endsWith("/save_web_workspace")).length).toBe(1);
    await page.locator(".ww-item").last().click(); await page.locator(".ww-item").first().click();
    await expect(saving).toBeDisabled();
    release(); await expect(page.getByText("הרשומה נשמרה", { exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "שמירת הרשומה", exact: true })).toBeEnabled();
    await expect(page.getByRole("button", {name:"שמירת הרשומה",exact:true})).toHaveCSS("background-color", "rgb(32, 62, 97)");
    await page.screenshot({path:`test-results/${type}-saved.png`,fullPage:true});
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
    await page.goto("/app/"); await page.getByRole("button", { name: "המשך המפגש", exact: true }).click(); await page.locator(".ww-item").first().click();
    await page.getByRole("button", { name: "שמירת הרשומה", exact: true }).click();
    await expect(page.getByText("הרשומה לא נשמרה", { exact: true })).toBeVisible();
    await page.screenshot({path:`test-results/${type}-${error}.png`,fullPage:true});
    await expect(page.locator('.ww-form-end button')).toHaveAttribute("aria-busy", "false");
    await expect(page.locator(".ww-sheet textarea").first()).toHaveValue('אמא אמרה: "לא!"');
    if (error === "network") { fail = false; await page.locator('.ww-form-end button').click(); await expect(page.getByText("הרשומה נשמרה", { exact: true })).toBeVisible(); }
  });
}
test("mobile scores and branding at desktop and narrow widths", async ({ page }) => {
  const item = createWorksheet("questionnaire");
  await fixture(page, { existing: true, payload: { version: 1, notes: "", items: [item] } });
  await page.goto("/app/"); await page.screenshot({ path: "test-results/branded-resume.png", fullPage: true });
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
  await page.goto("/app/login");
  for (const width of [1440,390]) {
    await page.setViewportSize({ width, height: 1000 });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    await expect(page.locator('img[alt="CBTipul"]:visible')).toBeVisible();
    await page.screenshot({ path: `test-results/branded-login-${width}.png`, fullPage: true });
  }
});

for (const type of ["diary_one", "diary_two", "diary_three"] as const) {
  test(`${type} compact worksheet picker, ratings and responsive edit preservation`, async ({ page }) => {
    const payload = diaryPayload(type);
    payload.items[0].data.feelings = [];
    const requests = await fixture(page, { existing: true, payload });
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.goto("/app/");
    await page.getByRole("button", { name: "המשך המפגש", exact: true }).click();
    await page.locator(".ww-item").first().click();
    if (type !== "diary_one") {
      await page.getByRole("button",{name:"בחירת טעויות חשיבה",exact:true}).click();
      const worksheetHeight = await page.locator(".ww-diary-grid").evaluate(el=>el.getBoundingClientRect().height);
      await page.getByLabel("הכל או כלום", {exact:true}).check();
      expect(await page.locator(".ww-diary-grid").evaluate(el=>el.getBoundingClientRect().height)).toBe(worksheetHeight);
      await page.screenshot({path:`test-results/${type}-error-picker.png`});
      await page.setViewportSize({width:390,height:844});
      const bounds = await page.locator(".ww-thinking-picker").evaluate(el => ({width:el.getBoundingClientRect().width,height:el.getBoundingClientRect().height}));
      expect(bounds.width).toBeLessThanOrEqual(390); expect(bounds.height).toBeLessThanOrEqual(844*.8+1);
      await page.screenshot({path:`test-results/${type}-error-picker-phone.png`});
      await page.setViewportSize({width:1366,height:768});
      await expect(page.getByLabel("לא זוהתה טעות חשיבה", {exact:true})).not.toBeChecked();
      await page.getByLabel("הכל או כלום", {exact:true}).uncheck();
      await expect(page.getByLabel("לא זוהתה טעות חשיבה", {exact:true})).not.toBeChecked();
      await page.getByRole("button",{name:"סיום הבחירה",exact:true}).click();
      await page.getByLabel("לא זוהתה טעות חשיבה", {exact:true}).check();
    }
    const event = page.locator(".ww-diary-section textarea").first();
    const long = 'אמא אמרה: "לא!"\n' + "טקסט עברי סינתטי ארוך, ללא מידע אמיתי. ".repeat(35);
    await event.fill(long);
    await page.getByRole("button", { name: "הוספת רגש", exact: true }).click();
    const picker = page.locator(".ww-feeling-picker:not(.ww-thinking-picker)");
    await expect(page.getByLabel("חיפוש רגש", { exact: true })).toBeFocused();
    await page.screenshot({path:`test-results/worksheet-${type}-picker.png`,fullPage:true});
    await expect(picker.getByRole("heading", { level: 3 })).toHaveText(["עצב", "חרדה", "אשמה ובושה", "חוסר ערך", "בדידות ודחייה", "מבוכה", "חוסר תקווה", "תסכול", "כעס"]);
    await picker.getByRole("button", { name: "מודאג", exact: true }).focus();
    await page.keyboard.press("Enter");
    await expect(page.getByRole("button", { name: "הוספת רגש", exact: true })).toBeFocused();
    const before = type === "diary_three" ? "עוצמה לפני — מודאג — אחוז" : "עוצמה — מודאג — אחוז";
    await expect(page.getByLabel(before, { exact: true })).toHaveValue(type === "diary_three" ? "" : "80");
    await page.getByLabel(before, { exact: true }).fill("0");
    const slider = page.getByLabel(before.replace("— אחוז", "— מחוון"), {exact:true});
    await slider.focus(); await page.keyboard.press("End");
    await expect(page.getByLabel(before, {exact:true})).toHaveValue("100");
    await page.keyboard.press("Home");
    await expect(page.getByLabel(before, {exact:true})).toHaveValue("0");
    await page.getByRole("button", { name: "הוספת רגש", exact: true }).click();
    await expect(picker.getByRole("button", { name: "מודאג", exact: true })).toHaveCount(0);
    await page.getByLabel("חיפוש רגש", { exact: true }).fill("חרד");
    await picker.getByRole("button", { name: "חרד", exact: true }).click();
    await page.getByRole("button", { name: "הוספת רגש", exact: true }).click();
    await picker.getByRole("button", { name: "רגש אחר", exact: true }).click();
    await picker.getByLabel("שם הרגש", { exact: true }).fill("מודאג");
    await picker.getByRole("button", { name: "הוספה", exact: true }).click();
    await expect(picker.getByRole("alert")).toHaveText("הרגש הזה כבר נבחר.");
    const custom = "רגש אישי סינתטי ארוך מאוד";
    await picker.getByLabel("שם הרגש", { exact: true }).fill(custom);
    await page.keyboard.press("Enter");
    await page.getByRole("button", { name: "הסרת רגש חרד", exact: true }).click();
    if (type === "diary_three") {
      await page.getByLabel("עוצמה אחרי — מודאג — אחוז", { exact: true }).fill("25");
      await page.getByLabel(`עוצמה לפני — ${custom} — אחוז`, { exact: true }).fill("80");
      await page.getByLabel(`עוצמה אחרי — ${custom} — אחוז`, { exact: true }).fill("50");
    }
    for (const [width,height] of [[1366,768],[1440,900],[1024,768],[390,844],[683,384]]) {
      await page.setViewportSize({ width,height });
      await expect(event).toHaveValue(long);
      await expect(page.getByLabel(before, { exact: true })).toHaveValue("0");
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
      const sections = await page.locator(".ww-diary-section").evaluateAll(els => els.map(el => { const r=el.getBoundingClientRect(); return { x:r.x,y:r.y,width:r.width }; }));
      for (let i=1;i<sections.length;i++) expect(sections[i].y > sections[i-1].y || sections[i].x < sections[i-1].x).toBe(true);
      await page.screenshot({ path: `test-results/worksheet-${type}-${width}.png`, fullPage: true });
    }
    await page.setViewportSize({width:1366,height:768});
    await page.evaluate(() => { document.documentElement.style.zoom = "2"; });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    await expect(event).toHaveValue(long);
    await page.screenshot({path:`test-results/worksheet-${type}-zoom200.png`,fullPage:true});
    await page.evaluate(() => { document.documentElement.style.zoom = ""; });
    await page.getByRole("button", { name: "שמירת הרשומה", exact: true }).click();
    await expect(page.getByText("הרשומה נשמרה", { exact: true })).toBeVisible();
    const sent = requests.filter(r => r.path.endsWith("/save_web_workspace")).at(-1)?.body?.p_payload as WorkspacePayload;
    expect(sent.items[0].data[type === "diary_three" ? "situation" : "event"]).toBe(long);
    expect(sent.items[0].data.feelings).toEqual(type === "diary_three" ? [{name:"מודאג",intensityBefore:0,intensityAfter:25},{name:custom,intensityBefore:80,intensityAfter:50}] : [{name:"מודאג",intensity:0},{name:custom,intensity:80}]);
    expect(requests.some(r => r.path.endsWith("/anonymize-clinical-text"))).toBe(false);
    await page.getByRole("button", {name:"הוספת רגש",exact:true}).click();
    await page.keyboard.press("Escape");
    await expect(picker).not.toBeVisible();
    await expect(page.getByRole("button", {name:"הוספת רגש",exact:true})).toBeFocused();
  });
  test(`${type} empty worksheet keeps incomplete validation separate from save failure`, async ({ page }) => {
    const item = createWorksheet(type);
    await fixture(page, {existing:true,payload:{version:1,notes:"",items:[item]}});
    await page.goto("/app/"); await page.getByRole("button", {name:"המשך המפגש",exact:true}).click(); await page.locator(".ww-item").first().click();
    await expect(page.getByRole("button", {name:"שמירת הרשומה",exact:true})).toBeDisabled();
    await expect(page.getByText("יש להשלים את שדות החובה לפני שמירת הרשומה. הטיוטה נשמרת אוטומטית.")).toBeVisible();
    await expect(page.getByText("הרשומה לא נשמרה",{exact:true})).toHaveCount(0);
    await page.screenshot({path:`test-results/worksheet-${type}-empty.png`,fullPage:true});
  });
}


test("shared authenticated navigation preserves the session, resumes work and exposes identical legal links", async({page})=>{
 const requests=await fixture(page);
 await page.goto("/app/");
 await expect(page.getByText("ממלאים יחד במפגש, משייכים למטופל/ת באפליקציה.")).toBeVisible();
 const footer=await page.locator(".cb-footer a").evaluateAll(links=>links.map(a=>[a.getAttribute("href"),a.textContent]));
 await page.getByRole("button",{name:"התחלת מפגש",exact:true}).click();
 await page.getByLabel("סיכום המפגש",{exact:true}).fill("תוכן סינתטי לניווט");await expect(page.getByText("כל השינויים נשמרו")).toBeVisible();
 await page.getByRole("link",{name:"לעמוד הבית",exact:true}).click();
 await expect(page).toHaveURL("/");await expect(page.locator(".site-nav .therapist-link")).toHaveText("למרחב העבודה");
 for(const width of [1366,390]){await page.setViewportSize({width,height:900});await expect(page.locator(".cb-header")).toHaveCount(1);await expect(page.locator(".cb-footer-links a")).toHaveCount(5);await page.screenshot({path:`test-results/shared-public-signed-in-${width}.png`,fullPage:true});}
 expect(await page.locator(".cb-footer a").evaluateAll(links=>links.map(a=>[a.getAttribute("href"),a.textContent]))).toEqual(footer);
 await page.locator(".cb-footer").getByRole("link",{name:"מדיניות פרטיות",exact:true}).click();await expect(page.locator(".site-nav .therapist-link")).toHaveText("למרחב העבודה");
 await page.locator(".site-nav .therapist-link").click();await expect(page.getByRole("button",{name:"המשך המפגש"})).toBeVisible();await page.getByRole("button",{name:"המשך המפגש"}).click();
 await expect(page.getByLabel("סיכום המפגש",{exact:true})).toHaveValue("אנונימי: תוכן סינתטי לניווט");
 expect(requests.filter(r=>r.path.endsWith("/record_my_consent"))).toHaveLength(0);
 await page.getByRole("link",{name:"לעמוד הבית",exact:true}).click();await page.getByRole("button",{name:"התנתקות",exact:true}).click();await expect(page.locator(".site-nav .therapist-link")).toHaveText("כניסה למטפלים");await page.locator(".site-nav .therapist-link").click();await expect(page).toHaveURL(/app\/login$/);
});

test("failed consent lookup does not redisplay acceptance and ignores legacy browser flags",async({page})=>{
 const options={lookupFail:true};const requests=await fixture(page,options);await page.goto("/app/");await expect(page.getByText(/לא ניתן לבדוק את האישור בשרת/)).toBeVisible();await expect(page.getByRole("button",{name:"קראתי ואני מסכים/ה"})).toHaveCount(0);expect(requests.some(r=>r.path.endsWith("/begin_web_workspace"))).toBe(false);options.lookupFail=false;await page.getByRole("button",{name:"ניסיון נוסף",exact:true}).click();await expect(page.getByRole("button",{name:"התחלת מפגש"})).toBeVisible();
});

test("consent acceptance waits for server persistence, survives reload and does not grant clinical consent",async({page})=>{
 const options={terms:false,consent:false,persistFail:true};const requests=await fixture(page,options);await page.goto("/app/");await page.getByRole("button",{name:"קראתי ואני מסכים/ה"}).click();await expect(page.getByText(/הבחירה לא אושרה בשרת/)).toBeVisible();await expect(page.getByRole("button",{name:"התחלת מפגש"})).toHaveCount(0);options.persistFail=false;await page.getByRole("button",{name:"ניסיון נוסף",exact:true}).click();await expect(page.getByRole("button",{name:"התחלת מפגש"})).toBeVisible();await page.reload();await page.getByRole("button",{name:"התחלת מפגש"}).click();await page.getByLabel("סיכום המפגש",{exact:true}).fill("סיכום סינתטי לאישור");await expect(page.getByRole("button",{name:"אני מאשר/ת את העיבוד והשמירה"})).toBeVisible();expect(requests.filter(r=>r.path.endsWith("/anonymize-clinical-text"))).toHaveLength(0);await page.getByRole("button",{name:"לא עכשיו",exact:true}).click();await expect(page.getByLabel("סיכום המפגש",{exact:true})).toHaveValue("סיכום סינתטי לאישור");await page.getByRole("button",{name:"אני מאשר/ת את העיבוד והשמירה"}).click();await expect(page.getByText("כל השינויים נשמרו")).toBeVisible();
});

test("leaving during a pending save warns and cancellation retains entered content",async({page})=>{
 let release!:()=>void;const gate=new Promise<void>(r=>{release=r;});await fixture(page,{beforeSave:async()=>{await gate;return undefined;}});await page.goto("/app/");await page.getByRole("button",{name:"התחלת מפגש"}).click();await page.getByLabel("סיכום המפגש",{exact:true}).fill("טיוטה סינתטית ממתינה");await expect(page.locator(".ww-save-saving")).toBeVisible();let warned=false;page.once("dialog",async d=>{warned=d.type()==="beforeunload";await d.dismiss();});await page.getByRole("link",{name:"לעמוד הבית",exact:true}).click();expect(warned).toBe(true);await expect(page.getByLabel("סיכום המפגש",{exact:true})).toHaveValue("טיוטה סינתטית ממתינה");release();await expect(page.getByText("כל השינויים נשמרו")).toBeVisible();
});

test("account switching rechecks consent and clears account-specific state",async({page})=>{
 const options:{account?:typeof user;terms?:boolean}={};const requests=await fixture(page,options);await page.goto("/app/");await expect(page.getByRole("button",{name:"התחלת מפגש"})).toBeVisible();options.account={...user,id:"second-therapist",email:"second@example.invalid"};options.terms=false;await page.evaluate(account=>{const key="cbtipul.web.auth";const newValue=JSON.stringify({access_token:"second-token",refresh_token:"second-refresh",expires_at:Math.floor(Date.now()/1000)+3600,token_type:"bearer",user:account});localStorage.setItem(key,newValue);const channel=new BroadcastChannel(key);channel.postMessage({event:"SIGNED_IN",session:JSON.parse(newValue)});channel.close();},options.account);await expect(page.getByRole("button",{name:"קראתי ואני מסכים/ה"})).toBeVisible();expect(requests.filter(r=>r.path.endsWith("/record_my_consent"))).toHaveLength(0);await expect(page.getByRole("button",{name:"התחלת מפגש"})).toHaveCount(0);
});


test("server acceptance survives a new workspace and subsequent login; revocation requires new clinical consent",async({page})=>{
 const requests=await fixture(page);await page.goto("/app/");await page.getByRole("button",{name:"התחלת מפגש",exact:true}).click();await page.getByLabel("סיכום המפגש",{exact:true}).fill("מפגש סינתטי ראשון");await expect(page.getByText("כל השינויים נשמרו")).toBeVisible();await page.getByRole("button",{name:"סיום ושמירה",exact:true}).first().click();await page.getByRole("button",{name:"סיום ושמירה",exact:true}).last().click();await expect(page.getByRole("heading",{name:"המפגש נשמר"})).toBeVisible();await page.getByRole("button",{name:"התחלת מפגש חדש",exact:true}).click();await page.getByLabel("סיכום המפגש",{exact:true}).fill("מפגש סינתטי שני");await expect(page.getByText("כל השינויים נשמרו")).toBeVisible();expect(requests.some(r=>r.path.endsWith("/record_my_consent"))).toBe(false);
 await page.locator(".ww-help summary").click();await page.getByRole("button",{name:"ביטול האישור לעיבוד טקסט קליני"}).click();await expect(page.getByText(/האישור בוטל בחשבון/)).toBeVisible();await page.getByLabel("סיכום המפגש",{exact:true}).fill("שינוי סינתטי לאחר ביטול");await expect(page.getByRole("button",{name:"אני מאשר/ת את העיבוד והשמירה"})).toBeVisible();await page.getByRole("button",{name:"אני מאשר/ת את העיבוד והשמירה"}).click();await expect(page.getByText("כל השינויים נשמרו")).toBeVisible();
 await page.getByRole("button",{name:"התנתקות",exact:true}).click();await expect(page).toHaveURL(/app\/login$/);await page.getByLabel("דוא״ל",{exact:true}).fill("fixture@example.invalid");await page.getByLabel("סיסמה",{exact:true}).fill("synthetic-test-password");await page.getByRole("button",{name:"כניסה",exact:true}).click();await expect(page.getByRole("button",{name:"המשך המפגש"})).toBeVisible();await expect(page.getByRole("button",{name:"קראתי ואני מסכים/ה"})).toHaveCount(0);
});

test("shared start and resume guidance at laptop and phone widths",async({page})=>{
 await fixture(page);
 for(const width of [1366,390]){await page.setViewportSize({width,height:900});await page.goto("/app/");await expect(page.getByRole("heading",{name:"מרחב העבודה למטפלים"})).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);await page.screenshot({path:`test-results/shared-start-${width}.png`,fullPage:true});}
});


test("client navigation and logout both protect a pending workspace",async({page})=>{
 let release!:()=>void;const gate=new Promise<void>(r=>{release=r;});const requests=await fixture(page,{beforeSave:async()=>{await gate;return undefined;}});await page.goto("/app/legal/privacy");await page.locator(".legal > a").click();await page.getByRole("button",{name:"התחלת מפגש",exact:true}).click();await page.getByLabel("סיכום המפגש",{exact:true}).fill("סינתטי להגנת מעבר");await expect(page.locator(".ww-save-saving")).toBeVisible();let warned=false;page.once("dialog",async d=>{warned=d.type()==="confirm";await d.dismiss();});await page.evaluate(()=>history.back());await expect.poll(()=>warned).toBe(true);await expect(page.getByLabel("סיכום המפגש",{exact:true})).toHaveValue("סינתטי להגנת מעבר");page.once("dialog",d=>d.dismiss());await page.getByRole("button",{name:"התנתקות",exact:true}).click();expect(requests.some(r=>r.path.endsWith("/logout"))).toBe(false);release();await expect(page.getByText("כל השינויים נשמרו")).toBeVisible();
});


test("signed-in name follows the shared header and disappears on logout", async ({ page }) => {
  await fixture(page);
  await page.goto("/app/");
  await expect(page.locator(".cb-account-name")).toHaveText("ד״ר מטפל לדוגמה");
  await page.getByRole("link", { name: "לעמוד הבית", exact: true }).click();
  await expect(page.locator(".cb-account-name")).toHaveText("ד״ר מטפל לדוגמה");
  await page.setViewportSize({ width: 390, height: 844 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
  await page.getByRole("button", { name: "התנתקות", exact: true }).click();
  await expect(page.locator(".cb-account-name")).toHaveCount(0);
});


test("uncertain consent retry uses identical arguments and cannot undo a newer revocation", async ({ page }) => {
  const requests=await fixture(page,{terms:false,loseConsentResponse:true,consentInterveningRevocation:true});
  await page.goto("/app/");
  await page.getByRole("button",{name:"קראתי ואני מסכים/ה",exact:true}).click();
  await expect(page.getByText(/הבחירה לא אושרה בשרת/)).toBeVisible();
  await page.getByRole("button",{name:"ניסיון נוסף",exact:true}).click();
  await expect(page.getByText(/מצב האישור השתנה בחשבון/)).toBeVisible();
  await expect(page.getByRole("button",{name:"התחלת מפגש",exact:true})).toHaveCount(0);
  const writes=requests.filter(r=>r.path.endsWith("/record_my_consent"));
  expect(writes).toHaveLength(2);expect(writes[0].body).toEqual(writes[1].body);
  await page.screenshot({path:"test-results/consent-conflict-desktop.png"});
  await page.setViewportSize({width:390,height:844});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
  await page.screenshot({path:"test-results/consent-conflict-phone.png"});
  await page.getByRole("button",{name:"קראתי ואני מסכים/ה",exact:true}).click();
  await expect(page.getByRole("button",{name:"התחלת מפגש",exact:true})).toBeVisible();
  const final=requests.filter(r=>r.path.endsWith("/record_my_consent")).at(-1)!;
  expect(final.body?.p_expected_revision).toBe(2);
  expect(final.body?.p_request_id).not.toBe(writes[0].body?.p_request_id);
});

test("older wording acceptance prompts again and the new receipt survives reload",async({page})=>{
 const requests=await fixture(page,{terms:false,oldTermsVersion:true});
 await page.goto("/app/");
 await expect(page.getByRole("button",{name:"קראתי ואני מסכים/ה"})).toBeVisible();
 expect(requests.some(r=>r.path.endsWith("/get_active_web_workspace"))).toBe(false);
 await page.getByRole("button",{name:"קראתי ואני מסכים/ה"}).click();
 await expect(page.getByRole("button",{name:"התחלת מפגש",exact:true})).toBeVisible();
 await page.reload();
 await expect(page.getByRole("button",{name:"התחלת מפגש",exact:true})).toBeVisible();
 await expect(page.getByRole("button",{name:"קראתי ואני מסכים/ה"})).toHaveCount(0);
});
