import { workspaceClinicalAnonymizer } from "../data/api";
import { thinkingErrors, type WorkspacePayload } from "./model";

type TextAnonymizer = (text: string) => Promise<string>;
type Slot = { owner: Record<string, unknown> | unknown[]; key: string | number; original: string };
const record = (value: unknown): value is Record<string, unknown> => value !== null && typeof value === "object" && !Array.isArray(value);
const fail = (): never => { throw new Error("anonymization_shape"); };
const keys = (value: unknown, allowed: readonly string[]): Record<string, unknown> => {
  if (!record(value)) return fail();
  if (Object.keys(value).some((key) => !allowed.includes(key))) return fail();
  return value;
};
const numberOrNull = (value: unknown) => value === null || typeof value === "number" && Number.isFinite(value);

// Collect only known clinical text slots. Any unknown field fails closed so it
// cannot silently pass raw text into save_web_workspace.
export async function anonymizeWorkspacePayload(
  source: WorkspacePayload,
  account: string,
  create: (account: string) => Promise<TextAnonymizer> = workspaceClinicalAnonymizer,
): Promise<WorkspacePayload> {
  if (!record(source) || source.version !== 1 || !Array.isArray(source.items) || typeof source.notes !== "string" ||
      Object.keys(source).some((key) => !["version", "items", "notes"].includes(key))) fail();
  const copy = structuredClone(source);
  const slots: Slot[] = [];
  const text = (owner: Record<string, unknown> | unknown[], key: string | number) => {
    const value = (owner as Record<string | number, unknown>)[key];
    if (typeof value !== "string") return fail();
    slots.push({ owner, key, original: value });
  };
  const optionalText = (owner: Record<string, unknown>, key: string) => {
    if (Object.hasOwn(owner, key)) text(owner, key);
  };
  const textArray = (owner: Record<string, unknown>, key: string) => {
    if (!Object.hasOwn(owner, key)) return;
    const values = owner[key];
    if (!Array.isArray(values)) return fail();
    values.forEach((_, index) => text(values, index));
  };
  const objectArray = (owner: Record<string, unknown>, key: string, fields: readonly string[], textFields: readonly string[], numberFields: readonly string[]) => {
    if (!Object.hasOwn(owner, key)) return;
    const values = owner[key];
    if (!Array.isArray(values)) return fail();
    values.forEach((value) => {
      const entry = keys(value, fields);
      textFields.forEach((field) => optionalText(entry, field));
      numberFields.forEach((field) => { if (Object.hasOwn(entry, field) && !numberOrNull(entry[field])) fail(); });
    });
  };
  const ratings = (owner: Record<string, unknown>, key: string) => {
    if (!Object.hasOwn(owner, key)) return;
    const values = owner[key];
    if (!Array.isArray(values) || !values.every(numberOrNull)) fail();
  };
  const errors = (owner: Record<string, unknown>) => {
    const values = owner.thinking_errors;
    if (values === undefined || values === null) return;
    if (!Array.isArray(values) || !values.every((value) => typeof value === "string" && thinkingErrors.some(([code]) => code === value))) fail();
  };

  text(copy, "notes");
  for (const raw of copy.items) {
    const item = keys(raw, ["id", "type", "data", "completed_at", "measurement_date"]);
    if (typeof item.id !== "string" || typeof item.type !== "string" ||
        item.completed_at !== undefined && typeof item.completed_at !== "string" ||
        item.measurement_date !== undefined && typeof item.measurement_date !== "string") fail();
    const data = item.data;
    if (item.type === "questionnaire") {
      const d = keys(data, ["gad7_answers", "phq9_answers", "interference_level", "notes"]);
      ratings(d, "gad7_answers"); ratings(d, "phq9_answers");
      if (Object.hasOwn(d, "interference_level") && !numberOrNull(d.interference_level)) fail();
      optionalText(d, "notes");
    } else if (item.type === "diary_one" || item.type === "diary_two") {
      const d = keys(data, item.type === "diary_one"
        ? ["event", "automatic_thoughts", "feelings", "behaviour", "physical_symptoms"]
        : ["event", "automatic_thoughts", "feelings", "thinking_errors", "alternative_thoughts"]);
      optionalText(d, "event");
      textArray(d, "automatic_thoughts");
      objectArray(d, "feelings", ["name", "intensity"], ["name"], ["intensity"]);
      if (item.type === "diary_one") {
        optionalText(d, "behaviour"); optionalText(d, "physical_symptoms");
      } else {
        errors(d); textArray(d, "alternative_thoughts");
      }
    } else if (item.type === "diary_three") {
      const d = keys(data, ["situation", "automatic_thoughts", "feelings", "thinking_errors", "alternative_thoughts"]);
      optionalText(d, "situation");
      objectArray(d, "automatic_thoughts", ["text", "beliefBefore", "beliefAfter"], ["text"], ["beliefBefore", "beliefAfter"]);
      objectArray(d, "feelings", ["name", "intensityBefore", "intensityAfter"], ["name"], ["intensityBefore", "intensityAfter"]);
      errors(d);
      objectArray(d, "alternative_thoughts", ["text", "belief"], ["text"], ["belief"]);
    } else fail();
  }

  const anonymize = await create(account);
  for (const slot of slots) {
    const safe = await anonymize(slot.original);
    if (typeof safe !== "string" || slot.original.trim() && !safe.trim()) fail();
    (slot.owner as Record<string | number, unknown>)[slot.key] = safe;
  }
  return copy;
}
