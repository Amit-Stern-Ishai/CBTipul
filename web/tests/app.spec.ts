import { test, expect, type Page } from "@playwright/test";
const user = {
  id: "therapist-fixture",
  email: "fixture@example.invalid",
  is_anonymous: false,
  app_metadata: { provider: "email" },
  user_metadata: {},
  aud: "authenticated",
  created_at: "2026-01-01T00:00:00Z",
};
const p = {
  id: "p1",
  active: true,
  notes: "רקע סינתטי לבדיקה",
  formulation: { treatmentGoal: "לשפר את תחושת המסוגלות" },
};
const q = {
  id: "q1",
  patient_id: "p1",
  session_id: null,
  answered_date: "2026-10-01",
  created_by: "patient",
  gad7_answers: [1, 1, 1, 1, 1, 1, 1],
  phq9_answers: [0, 0, 0, 0, 0, 0, 0, 0, 1],
  interference_level: 1,
  combined_notes: null,
};
const session = {
  id: "s1",
  patient_id: "p1",
  session_date: "2026-10-02",
  type: "intake",
  notes: "סיכום סינתטי של פגישה",
  structured_notes: null,
};
async function fixture(
  page: Page,
  options: {
    role?: string;
    anonymous?: boolean;
    access?: string;
    loggedOut?: boolean;
  } = {},
) {
  const account = { ...user, is_anonymous: options.anonymous ?? false };
  let seen = false;
  const writes: { url: string; body: unknown }[] = [];
  await page.route("**/*", async (route) => {
    const url = new URL(route.request().url());
    if (url.hostname === "127.0.0.1") {
      await route.continue();
      return;
    }
    if (url.hostname !== "fixture.supabase.invalid") {
      await route.abort();
      return;
    }
    const path = url.pathname,
      method = route.request().method();
    const body =
      method === "POST" || method === "PATCH"
        ? route.request().postDataJSON()
        : null;
    if (method === "OPTIONS") {
      await route.fulfill({
        status: 200,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-headers": "*",
        },
      });
      return;
    }
    let data: unknown;
    if (path.endsWith("/user")) data = account;
    else if (path.endsWith("/logout")) data = {};
    else if (path.endsWith("/token"))
      data = {
        access_token: "fixture-token",
        refresh_token: "fixture-refresh",
        expires_in: 3600,
        token_type: "bearer",
        user: account,
      };
    else if (path.endsWith("/get-app-context"))
      data = {
        version: 1,
        role: options.role ?? "therapist",
        entitlement: { access: options.access ?? "full" },
      };
    else if (path.endsWith("/is_patient_connected")) data = true;
    else if (path.endsWith("/mark_notifications_seen")) {
      seen = true;
      data = null;
    } else if (path.endsWith("/mark_notification_read")) data = null;
    else if (path.endsWith("/anonymize-clinical-text"))
      data = { anonymizedText: body.text };
    else if (path.endsWith("/openai-gateway"))
      data = {
        choices: [{ message: { content: "תשובה סינתטית מתוך התיק בלבד." } }],
      };
    else if (path.endsWith("/prepare-session"))
      data = {
        preparation: {
          executive_summary: "הכנה סינתטית",
          priority_follow_ups: [],
        },
      };
    else if (path.endsWith("/analyze-session"))
      data = { analysis: { session_summary: "סיכום AI סינתטי" } };
    else if (path.endsWith("/therapist_profiles"))
      data = [{ therapist_id: user.id, display_name: "מטפל/ת לדוגמה" }];
    else if (path.endsWith("/Patients"))
      data =
        method === "POST"
          ? { ...p, id: "p2" }
          : method === "PATCH"
            ? { id: "p1" }
            : url.searchParams.has("id")
              ? p
              : [p, { ...p, id: "p2", formulation: null }];
    else if (path.endsWith("/Sessions"))
      data =
        method === "POST" || method === "PATCH"
          ? { ...session, ...body }
          : [session];
    else if (path.endsWith("/CombinedMood"))
      data = method === "POST" ? { id: "q2" } : [q];
    else if (path.endsWith("/patient_assignments"))
      data = [
        {
          id: "a1",
          patient_id: "p1",
          type: "questionnaire",
          session_id: null,
          cancelled_at: null,
          created_at: "2026-10-01",
        },
      ];
    else if (path.endsWith("/patient_messages")) data = [];
    else if (path.endsWith("/notifications"))
      data = [
        {
          id: "n1",
          type: "questionnaire_completed",
          patient_id: "p1",
          resource_type: "questionnaire",
          resource_id: "q1",
          read_at: null,
          seen_at: seen ? "2026-10-02" : null,
          created_at: "2026-10-02",
        },
      ];
    else if (path.match(/diary_(one|two|three)_entries$/))
      data = [
        {
          id: "d1",
          patient_id: "p1",
          created_by: "patient",
          created_at: "2026-10-02",
          updated_at: "2026-10-02",
          event: "אירוע סינתטי",
          situation: "מצב סינתטי",
          automatic_thoughts: ["מחשבה סינתטית"],
          feelings: [{ name: "עצב", intensity: 80 }],
          behaviour: "התנהגות סינתטית",
          thinking_errors: ["all_or_nothing"],
          alternative_thoughts: ["מחשבה חלופית"],
        },
      ];
    else {
      await route.abort();
      throw new Error(`Unexpected mocked endpoint: ${path}`);
    }
    if (method !== "GET") writes.push({ url: path, body });
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      headers: { "access-control-allow-origin": "*" },
      body: JSON.stringify(data),
    });
  });
  await page.addInitScript(
    ({ account, loggedOut }) => {
      if (loggedOut || sessionStorage.getItem("fixture-seeded")) return;
      sessionStorage.setItem("fixture-seeded", "yes");
      localStorage.setItem(
        "cbtipul.web.auth",
        JSON.stringify({
          access_token: "fixture-token",
          refresh_token: "fixture-refresh",
          expires_at: Math.floor(Date.now() / 1000) + 3600,
          token_type: "bearer",
          user: account,
        }),
      );
      localStorage.setItem(`cbtipul.terms.${account.id}`, "2026-08-29");
      localStorage.setItem(`cbtipul.ai.${account.id}`, "yes");
      localStorage.setItem(`cbtipul.names.${account.id}.p1`, "דנה לוי");
    },
    { account, loggedOut: options.loggedOut ?? false },
  );
  return writes;
}
test("desktop patient navigation, exact notification result and logout cleanup", async ({
  page,
}) => {
  await fixture(page);
  await page.goto("/patients");
  await expect(
    page.getByRole("heading", { name: "המטופלים שלי" }),
  ).toBeVisible();
  await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
  await page.getByRole("link", { name: /דנה לוי/ }).click();
  await expect(
    page.getByRole("heading", { name: "דנה לוי", exact: true }),
  ).toBeVisible();
  await page.getByRole("link", { name: /^עדכונים/ }).click();
  await page.getByRole("link", { name: /לצפייה בשאלון/ }).click();
  await expect(
    page.getByRole("heading", { name: "שאלון מצב רוח", exact: true }),
  ).toBeVisible();
  await expect(page.getByText(/צפייה בלבד/)).toBeVisible();
  await page.goBack();
  await expect(page.getByRole("heading", { name: "עדכונים" })).toBeVisible();
  await page.getByRole("button", { name: "התנתקות", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "טוב לראות אותך" }),
  ).toBeVisible();
  expect(
    await page.evaluate(() =>
      Object.keys(localStorage).filter((k) => k.startsWith("cbtipul.names.")),
    ),
  ).toEqual([]);
  await page.goBack();
  await expect(
    page.getByRole("heading", { name: "טוב לראות אותך" }),
  ).toBeVisible();
});
test("session editor guards dirty navigation and can save empty notes", async ({
  page,
}) => {
  const writes = await fixture(page);
  await page.goto("/patients/p1/sessions/s1");
  await page.getByLabel("סיכום הפגישה", { exact: true }).fill("");
  await page.getByRole("link", { name: "מטופלים", exact: true }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.getByRole("button", { name: "חזרה לעריכה" }).click();
  await page.getByRole("button", { name: "שמירת סיכום", exact: true }).click();
  await expect(page.getByText("הסיכום נשמר.")).toBeVisible();
  expect(writes.find((w) => w.url.endsWith("/Sessions"))?.body).toMatchObject({
    notes: "",
    patient_id: "p1",
  });
});
test("local name never enters AI payload; patient context includes diaries", async ({
  page,
}) => {
  const writes = await fixture(page);
  await page.goto("/patients/p1/ai");
  await page.getByLabel("שאלה על התיק הטיפולי").fill("מה השתנה אצל דנה לוי?");
  await page.getByRole("button", { name: "שליחת שאלה" }).click();
  await expect(page.getByText("תשובה סינתטית מתוך התיק בלבד.")).toBeVisible();
  expect(JSON.stringify(writes)).not.toContain("דנה לוי");
  const gateway = writes.find((w) => w.url.endsWith("/openai-gateway"));
  expect(JSON.stringify(gateway)).toContain("אירוע סינתטי");
  expect(JSON.stringify(gateway)).toContain("לשפר את תחושת המסוגלות");
});
test("read-only permits local rename but hides creation and disables clinical editing", async ({
  page,
}) => {
  const writes = await fixture(page, { access: "read_only" });
  await page.goto("/patients");
  await expect(page.getByText(/מצב צפייה בלבד/)).toBeVisible();
  await expect(page.getByRole("link", { name: "הוספת מטופל/ת" })).toHaveCount(
    0,
  );
  await page.goto("/patients/p1/edit");
  await expect(page.getByLabel("מטרת הטיפול")).toBeDisabled();
  await page.getByLabel("שם לתצוגה בדפדפן").fill("שם חדש");
  await page.getByRole("button", { name: "שמירת מטופל/ת" }).click();
  await expect(
    page.getByRole("heading", { name: "שם חדש", exact: true }),
  ).toBeVisible();
  expect(
    writes.filter((w) => w.url.includes("/rest/v1/Patients")),
  ).toHaveLength(0);
});
test("patient and anonymous accounts never fetch clinical therapist records", async ({
  page,
}) => {
  const writes = await fixture(page, { role: "patient", anonymous: true });
  await page.goto("/patients");
  await expect(
    page.getByRole("heading", { name: "המרחב הזה מיועד למטפלים" }),
  ).toBeVisible();
  expect(writes.filter((w) => w.url.includes("/rest/v1/"))).toHaveLength(0);
});
test("small screen forms and graphs fit viewport and keyboard navigation works", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await fixture(page);
  await page.goto("/patients/p1/questionnaires");
  await page.getByRole("tab", { name: "גרפים ומגמות" }).click();
  await expect(page.getByLabel("מגמה", { exact: true })).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await page.goto("/patients/p1/questionnaires/new");
  await expect(
    page.getByRole("button", { name: "שמירת שאלון" }),
  ).toBeDisabled();
  await page.getByLabel("תאריך המדידה").focus();
  await page.keyboard.press("Tab");
  expect(
    await page.evaluate(() => document.activeElement !== document.body),
  ).toBe(true);
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({
    path: "test-results/questionnaire-mobile.png",
    fullPage: true,
  });
});
test("login page does not access backend before sign in", async ({ page }) => {
  const writes = await fixture(page, { loggedOut: true });
  await page.goto("/login");
  await expect(
    page.getByRole("button", { name: "כניסה באמצעות Google" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "כניסה באמצעות Apple" }),
  ).toBeVisible();
  expect(writes).toHaveLength(0);
  await page.screenshot({
    path: "test-results/login-desktop.png",
    fullPage: true,
  });
});
test("questionnaire entry sends date and exact 0–3 answers, with patient-level ownership", async ({
  page,
}) => {
  const writes = await fixture(page);
  await page.goto("/patients/p1/questionnaires/new");
  await page.getByLabel("תאריך המדידה").fill("2026-09-30");
  for (let i = 0; i < 16; i++) {
    await page.locator(`input[name="q-${i}"][value="1"]`).check();
  }
  await page.locator('input[name="interference"]').nth(2).check();
  await page.getByRole("button", { name: "שמירת שאלון" }).click();
  await expect
    .poll(() => writes.some((w) => w.url.endsWith("/CombinedMood")))
    .toBe(true);
  expect(
    writes.find((w) => w.url.endsWith("/CombinedMood"))?.body,
  ).toMatchObject({
    patient_id: "p1",
    session_id: null,
    answered_date: "2026-09-30",
    gad7_answers: Array(7).fill(1),
    phq9_answers: Array(9).fill(1),
    interference_level: 2,
  });
});
test("desktop and tablet patient overview, and patient-authored diaries remain read-only", async ({
  page,
}) => {
  await fixture(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/patients/p1");
  await expect(
    page.getByRole("heading", { name: "דנה לוי", exact: true }),
  ).toBeVisible();
  await page.screenshot({
    path: "test-results/patient-desktop.png",
    fullPage: true,
  });
  await page.setViewportSize({ width: 834, height: 1112 });
  await page.reload();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await page.goto("/patients/p1/diaries/2/d1");
  await expect(
    page.getByRole("heading", { name: "רשומה ביומן מחשבות 2" }),
  ).toBeVisible();
  await expect(page.getByText("הכל או כלום")).toBeVisible();
  await expect(page.getByRole("textbox")).toHaveCount(0);
  await expect(page.getByText(/צפייה בלבד/)).toBeVisible();
  await page.screenshot({
    path: "test-results/diary-tablet.png",
    fullPage: true,
  });
});
test("non-anonymous patient role cannot enter therapist screens", async ({
  page,
}) => {
  await fixture(page, { role: "patient", anonymous: false });
  await page.goto("/patients/p1");
  await expect(
    page.getByRole("heading", { name: "המרחב הזה מיועד למטפלים" }),
  ).toBeVisible();
  await expect(page.getByRole("heading", { name: "דנה לוי" })).toHaveCount(0);
});

const browserErrors=new WeakMap<Page,string[]>();
test.beforeEach(({page})=>{const errors:string[]=[];browserErrors.set(page,errors);page.on('pageerror',error=>errors.push(error.message));page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});});
test.afterEach(({page})=>{expect(browserErrors.get(page)??[]).toEqual([]);});
