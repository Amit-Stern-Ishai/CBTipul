import { describe, it, expect } from "vitest";
import { score, dateOnly, trend, measurementDate } from "./questionnaires";
import { names, therapistAllowed } from "./privacy";
import { chatContext, preparationContext } from "./context";
import type { Bundle, Questionnaire } from "./types";
function storage(): Storage {
  const values: Record<string, string> = {};
  return new Proxy(
    {
      getItem: (key: string) => values[key] ?? null,
      setItem: (key: string, value: string) => {
        values[key] = value;
      },
      removeItem: (key: string) => {
        delete values[key];
      },
      clear: () => {
        Object.keys(values).forEach((key) => delete values[key]);
      },
      key: (i: number) => Object.keys(values)[i] ?? null,
      get length() {
        return Object.keys(values).length;
      },
    },
    {
      ownKeys: () => Object.keys(values),
      getOwnPropertyDescriptor: () => ({
        enumerable: true,
        configurable: true,
      }),
    },
  ) as Storage;
}
const questionnaire: Questionnaire = {
  id: "q1",
  patient_id: "p1",
  session_id: null,
  answered_date: "2026-10-01",
  created_at: "2026-10-03T23:59:00Z",
  created_by: "patient",
  gad7_answers: [0, 1, 2, 3, 0, 1, 2],
  phq9_answers: [0, 0, 0, 0, 0, 0, 0, 0, 1],
  interference_level: 1,
  combined_notes: null,
};
const bundle: Bundle = {
  patient: {
    id: "p1",
    active: true,
    notes: "מידע כללי",
    formulation: {
      treatmentGoal: "מטרת טיפול מלאה ".repeat(200),
      therapistHypothesis: "השערה בלבד",
    },
  },
  sessions: [
    {
      id: "s1",
      patient_id: "p1",
      session_date: "2026-10-02",
      type: "intake",
      notes: "סיכום מקורי",
      structured_notes: {
        session_summary: "סיכום AI",
        follow_up_questions: [
          { question: "שאלה פתוחה", reason: "סיבה", status: "follow_up" },
          { question: "כבר נדון", status: "discussed" },
        ],
      },
    },
  ],
  questionnaires: [questionnaire],
  diaries: [
    [
      {
        id: "d1",
        patient_id: "p1",
        created_by: "patient",
        created_at: "2026-10-03T12:00:00Z",
        updated_at: "2026-10-03T12:00:00Z",
        event: "אירוע",
        automatic_thoughts: ["מחשבה"],
        feelings: [{ name: "עצב", intensity: 80 }],
        behaviour: "התנהגות",
      },
    ],
    [],
    [],
  ],
  unavailable: ["diary_2"],
};
describe("authorization boundary", () => {
  it.each([null, { is_anonymous: true }, {}])(
    "denies anonymous or unknown users: %j",
    (user) => expect(therapistAllowed(user, { role: "therapist" })).toBe(false),
  );
  it("requires server therapist role", () => {
    expect(therapistAllowed({ is_anonymous: false }, null)).toBe(false);
    expect(therapistAllowed({ is_anonymous: false }, { role: "patient" })).toBe(
      false,
    );
    expect(
      therapistAllowed({ is_anonymous: false }, { role: "therapist" }),
    ).toBe(true);
  });
});
describe("questionnaires", () => {
  it("scores only complete valid scales", () => {
    expect(score(Array(7).fill(3), 7)).toBe(21);
    expect(score(Array(9).fill(3), 9)).toBe(27);
    expect(score([0, 1], 7)).toBeNull();
    expect(score([0, 1, 2, 3, 4, 0, 0], 7)).toBeNull();
    expect(score([0, 1, 2, 3, -1, 0, 0], 7)).toBeNull();
    expect(score([0, 1, 2, 3, 1.5, 0, 0], 7)).toBeNull();
  });
  it("preserves measurement date independently of creation time", () => {
    expect(measurementDate(questionnaire)).toBe("2026-10-01");
    expect(
      measurementDate({ ...questionnaire, answered_date: null }),
    ).toBeNull();
    expect(dateOnly("2024-02-29")).toBe("2024-02-29");
    expect(() => dateOnly("2026-02-30")).toThrow();
    expect(() => dateOnly("2026-10-01T00:00:00Z")).toThrow();
  });
  it.each([
    [[3, 2, 2, 1], 0],
    [[3, 1, 2], 1],
    [[2, 2, 2], 2],
    [[1, 3, 2], 3],
    [[0, 1, 1, 3], 4],
    [[null, 1], 5],
    [[1, 2, 1], 2],
  ])("matches mobile trend behavior for %j", (values, result) =>
    expect(trend(values as (number | null)[])).toBe(result),
  );
});
describe("local names", () => {
  it("isolates accounts and removes only the logged-out account", () => {
    const s = storage();
    names.set(s, "therapist-a", "p1", "דנה לוי");
    names.set(s, "therapist-b", "p1", "שם אחר");
    expect(names.get(s, "therapist-a", "p1")).toBe("דנה לוי");
    expect(names.get(s, "therapist-b", "p1")).toBe("שם אחר");
    names.clear(s, "therapist-a");
    expect(names.get(s, "therapist-a", "p1")).toBe("");
    expect(names.get(s, "therapist-b", "p1")).toBe("שם אחר");
  });
  it("redacts known display names before a network boundary", () => {
    const s = storage();
    names.set(s, "a", "p1", "דנה לוי");
    const safe = names.redact(s, "a", "דנה לוי סיפרה. דנה חושבת.");
    expect(safe).not.toContain("דנה");
    expect(safe).not.toContain("לוי");
  });
});
describe("AI context", () => {
  it("preserves full goal, source, patient reports and explicit missing history", () => {
    const context = chatContext(bundle);
    expect(context).toContain(bundle.patient.formulation!.treatmentGoal);
    expect(context).toContain("סיכום מקורי");
    expect(context).toContain("ai_generated");
    expect(context).toContain("patient_reported_measurement");
    expect(context).toContain('"author":"patient"');
    expect(context).toContain(
      "record creation time, not necessarily the event date",
    );
    expect(context).toContain("loading failed; history is unknown");
    expect(context).not.toContain('"patient_id"');
    expect(context).not.toContain('"id":"p1"');
  });
  it("never serializes injected local identity fields", () => {
    const withName = {
      ...bundle,
      patient: {
        ...bundle.patient,
        localName: "PRIVATE LOCAL NAME",
        firstName: "PRIVATE FIRST",
      },
    };
    expect(chatContext(withName)).not.toContain("PRIVATE");
    expect(JSON.stringify(preparationContext(withName))).not.toContain(
      "PRIVATE",
    );
  });
  it("keeps prep contract and excludes resolved follow-ups", () => {
    const context = preparationContext(bundle);
    expect(context.overview.treatment_goals).toBe(
      bundle.patient.formulation!.treatmentGoal,
    );
    expect(context.open_follow_ups).toHaveLength(1);
    expect(context.recent_reviews[0].summary).toBe("סיכום AI");
  });
});
it("privacy redaction preserves protocol keys and provenance metadata", async () => {
  const { safeBundle } = await import("./context");
  const redacted = safeBundle(bundle, (text) =>
    text.replaceAll("מחשבה", "[מטופל/ת]").replaceAll("therapist", "[מטופל/ת]"),
  );
  const context = chatContext(redacted);
  expect(context).toContain('"source":"therapist"');
  expect(context).toContain('"automaticThoughts"');
  expect(context).not.toContain('"automaticThoughts":["מחשבה"]');
});
