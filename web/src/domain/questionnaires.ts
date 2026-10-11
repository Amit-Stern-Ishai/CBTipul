import { he } from "../he";
import type { Questionnaire } from "./types";
export function score(values: readonly number[], count: number): number | null {
  return values.length === count &&
    values.every((v) => Number.isInteger(v) && v >= 0 && v <= 3)
    ? values.reduce((a, b) => a + b, 0)
    : null;
}
export function dateOnly(value: string): string {
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
    new Date(`${value}T12:00:00Z`).toISOString().slice(0, 10) !== value
  )
    throw new Error(he.questionnaires001);
  return value;
}
export function measurementDate(q: Questionnaire): string | null {
  return q.answered_date ? dateOnly(q.answered_date.slice(0, 10)) : null;
}
export const trendLabels = [
  he.questionnaires002,
  he.questionnaires003,
  he.questionnaires004,
  he.questionnaires005,
  he.questionnaires006,
  he.questionnaires007,
];
export function trend(values: (number | null)[]): number {
  const a = values.filter(
    (v): v is number => v !== null && Number.isInteger(v) && v >= 0 && v <= 3,
  );
  if (a.length < 2) return 5;
  if (a.every((v) => v === a[0])) return 2;
  if (a.slice(1).every((v, i) => v <= a[i])) return 0;
  if (a.slice(1).every((v, i) => v >= a[i])) return 4;
  return a.at(-1)! < a[0] ? 1 : a.at(-1)! > a[0] ? 3 : 2;
}
export function chronological(rows: Questionnaire[]) {
  return [...rows]
    .filter((q) => q.answered_date)
    .sort((a, b) => a.answered_date!.localeCompare(b.answered_date!));
}
