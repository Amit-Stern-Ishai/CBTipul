import { workspaceClinicalAnonymizer } from "../data/api";
import { thinkingErrors, type WorkspacePayload } from "./model";

export type NotesCache = Map<string, { original: string; safe: string }>;

type TextAnonymizer = (text: string) => Promise<string>;
type Slot = { owner: Record<string, unknown> | unknown[]; key: string | number; original: string; path: string };
const record = (value: unknown): value is Record<string, unknown> => value !== null && typeof value === "object" && !Array.isArray(value);
const fail = (): never => { throw new Error("anonymization_shape"); };
const keys = (value: unknown, allowed: readonly string[]): Record<string, unknown> => {
  if (!record(value)) return fail();
  if (Object.keys(value).some((key) => !allowed.includes(key))) return fail();
  return value;
};
const numberOrNull = (value: unknown) => value === null || typeof value === "number" && Number.isFinite(value);

// Validate every field, but only session/questionnaire notes cross the AI boundary.
// Diary text is deliberately preserved, including whitespace and nested wording.
export async function anonymizeWorkspacePayload(
  source: WorkspacePayload,
  account: string,
  create: (account: string) => Promise<TextAnonymizer> = workspaceClinicalAnonymizer,
  cache: NotesCache = new Map(),
): Promise<WorkspacePayload> {
  if (!record(source) || source.version !== 1 || !Array.isArray(source.items) || typeof source.notes !== "string" ||
      Object.keys(source).some((key) => !["version", "items", "notes"].includes(key))) fail();
  const copy = structuredClone(source);
  const slots: Slot[] = [];
  let collect = true;
  let path = "notes";
  const text = (owner: Record<string, unknown> | unknown[], key: string | number) => {
    const value = (owner as Record<string | number, unknown>)[key];
    if (typeof value !== "string") return fail();
    if (collect) slots.push({ owner, key, original: value, path });
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
    collect = item.type === "questionnaire";
    path = String(item.id);
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

  let anonymize: TextAnonymizer | undefined;
  const nextCache: NotesCache = new Map();
  for (const slot of slots) {
    const cacheKey = JSON.stringify([account, slot.path, slot.key]);
    const previous = cache.get(cacheKey);
    if (!slot.original.trim()) { nextCache.set(cacheKey, { original: slot.original, safe: slot.original }); continue; }
    let safe = previous?.original === slot.original ? previous.safe : undefined;
    if (safe === undefined) {
      anonymize ??= await create(account);
      safe = await anonymize(slot.original);
    }
    if (typeof safe !== "string" || slot.original.trim() && !safe.trim()) fail();
    nextCache.set(cacheKey, { original: slot.original, safe });
    (slot.owner as Record<string | number, unknown>)[slot.key] = safe;
  }
  cache.clear();
  nextCache.forEach((value, key) => cache.set(key, value));
  return copy;
}

// This cache lives only in the engine instance, never in browser storage.
export function createWorkspaceAnonymizer(create: (account: string) => Promise<TextAnonymizer> = workspaceClinicalAnonymizer) {
  const cache: NotesCache = new Map();
  return Object.assign(
    (payload: WorkspacePayload, account: string) => anonymizeWorkspacePayload(payload, account, create, cache),
    { seed(payload: WorkspacePayload, account: string) {
      // The server snapshot already contains safe notes. Only edits need AI.
      cache.clear();
      cache.set(JSON.stringify([account, "notes", "notes"]), { original: payload.notes, safe: payload.notes });
      for (const item of payload.items) if (item.type === "questionnaire" && typeof item.data.notes === "string") {
        cache.set(JSON.stringify([account, item.id, "notes"]), { original: item.data.notes, safe: item.data.notes });
      }
    } },
  );
}
