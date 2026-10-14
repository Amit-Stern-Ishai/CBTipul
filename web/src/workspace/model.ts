import { score, dateOnly } from "../domain/questionnaires";

export type WorksheetType = "questionnaire" | "diary_one" | "diary_two" | "diary_three";
export type Worksheet = {
  id: string;
  type: WorksheetType;
  data: Record<string, unknown>;
  completed_at?: string;
  measurement_date?: string;
};
export type WorkspacePayload = { version: 1; items: Worksheet[]; notes: string };
export type WorkspaceEnvelope = {
  id: string;
  status: "active" | "pending" | "associated" | "discarded";
  started_at: string;
  updated_at: string;
  revision: number;
  payload: WorkspacePayload;
  lease_token?: string;
  lease_until?: string;
};

export const thinkingErrors = [
  ["all_or_nothing", "thinking_error_all_or_nothing"],
  ["overgeneralization", "thinking_error_overgeneralization"],
  ["negative_filter", "thinking_error_negative_filter"],
  ["discounting_positives", "thinking_error_discounting_positives"],
  ["jumping_to_conclusions", "thinking_error_jumping_to_conclusions"],
  ["mind_reading", "thinking_error_mind_reading"],
  ["fortune_telling", "thinking_error_fortune_telling"],
  ["magnification_minimization", "thinking_error_magnification_minimization"],
  ["emotional_reasoning", "thinking_error_emotional_reasoning"],
  ["should_statements", "thinking_error_should_statements"],
  ["labeling", "thinking_error_labeling"],
  ["blame", "thinking_error_blame"],
] as const;

export function todayLocal(now = new Date()) {
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function createWorksheet(type: WorksheetType, now = new Date()): Worksheet {
  const common = { id: crypto.randomUUID(), type };
  if (type === "questionnaire") return {
    ...common,
    measurement_date: todayLocal(now),
    data: { gad7_answers: Array(7).fill(null), phq9_answers: Array(9).fill(null), interference_level: null, notes: "" },
  };
  if (type === "diary_one") return { ...common, data: { event: "", automatic_thoughts: [""], feelings: [{ name: "", intensity: 0 }], behaviour: "", physical_symptoms: "" } };
  if (type === "diary_two") return { ...common, data: { event: "", automatic_thoughts: [""], feelings: [{ name: "", intensity: 0 }], thinking_errors: null, alternative_thoughts: [""] } };
  return { ...common, data: { situation: "", automatic_thoughts: [{ text: "", beliefBefore: 0, beliefAfter: 0 }], feelings: [{ name: "", intensityBefore: 0, intensityAfter: 0 }], thinking_errors: null, alternative_thoughts: [{ text: "", belief: 0 }] } };
}

const nonempty = (v: unknown) => typeof v === "string" && v.trim().length > 0 && v.length <= 50000;
const rating = (v: unknown, max: number) => Number.isInteger(v) && Number(v) >= 0 && Number(v) <= max;
const list = (v: unknown, test: (x: unknown) => boolean) => Array.isArray(v) && v.length >= 1 && v.length <= 100 && v.every(test);
const object = (v: unknown): v is Record<string, unknown> => !!v && typeof v === "object" && !Array.isArray(v);
const fields = (v: unknown, name: string, ratings: readonly string[]) => object(v) && nonempty(v[name]) && ratings.every((key) => rating(v[key], 100));
const validErrors = (v: unknown) => Array.isArray(v) && v.length <= 100 && v.every((x) => typeof x === "string" && thinkingErrors.some(([code]) => code === x)) && new Set(v as string[]).size === v.length;

export function isFormComplete(item: Worksheet): boolean {
  const d = item.data;
  if (!object(d)) return false;
  if (item.type === "questionnaire") {
    try { if (!item.measurement_date || dateOnly(item.measurement_date) !== item.measurement_date) return false; } catch { return false; }
    if (!Array.isArray(d.gad7_answers) || !Array.isArray(d.phq9_answers)) return false;
    return score(d.gad7_answers as number[], 7) !== null && score(d.phq9_answers as number[], 9) !== null && rating(d.interference_level, 3) && (d.notes === undefined || typeof d.notes === "string" && d.notes.length <= 50000);
  }
  const lead = item.type === "diary_three" ? "situation" : "event";
  if (!nonempty(d[lead])) return false;
  if (item.type === "diary_three") {
    return list(d.automatic_thoughts, (v) => fields(v, "text", ["beliefBefore", "beliefAfter"]))
      && list(d.feelings, (v) => fields(v, "name", ["intensityBefore", "intensityAfter"]))
      && validErrors(d.thinking_errors)
      && list(d.alternative_thoughts, (v) => fields(v, "text", ["belief"]))
      && new Set((d.feelings as { name: string }[]).map((f) => f.name.trim())).size === (d.feelings as unknown[]).length;
  }
  if (!list(d.automatic_thoughts, nonempty) || !list(d.feelings, (v) => fields(v, "name", ["intensity"]))) return false;
  if (new Set((d.feelings as { name: string }[]).map((f) => f.name.trim())).size !== (d.feelings as unknown[]).length) return false;
  if (item.type === "diary_one") return nonempty(d.behaviour) && (d.physical_symptoms === undefined || typeof d.physical_symptoms === "string" && d.physical_symptoms.length <= 50000);
  return validErrors(d.thinking_errors) && list(d.alternative_thoughts, nonempty);
}

export function finishProblems(payload: WorkspacePayload): string[] {
  const issues: string[] = [];
  if (payload.items.length === 0 && !payload.notes.trim()) issues.push("empty");
  payload.items.forEach((item) => {
    if (!isFormComplete(item) || !item.completed_at || !Number.isFinite(Date.parse(item.completed_at))) issues.push(item.id);
  });
  if (payload.notes.length > 50000 || payload.items.length > 100) issues.push("limit");
  return issues;
}

export function markComplete(item: Worksheet, now = new Date()): Worksheet {
  if (!isFormComplete(item)) throw new Error("incomplete");
  return { ...item, completed_at: item.completed_at ?? now.toISOString() };
}

export function updateItem(item: Worksheet, change: Partial<Worksheet> & { data?: Record<string, unknown> }): Worksheet {
  const updated = { ...item, ...change, data: change.data ? { ...item.data, ...change.data } : item.data };
  // A clinical edit requires a fresh, explicit completion acknowledgement.
  if (change.data || change.measurement_date !== undefined) delete updated.completed_at;
  return updated;
}

export function questionnaireFlags(item: Worksheet) {
  if (item.type !== "questionnaire") return null;
  const gad = Array.isArray(item.data.gad7_answers) ? item.data.gad7_answers as number[] : [];
  const phq = Array.isArray(item.data.phq9_answers) ? item.data.phq9_answers as number[] : [];
  return { gad: score(gad, 7), phq: score(phq, 9), question9: Number(phq?.[8] ?? 0) > 0 };
}
