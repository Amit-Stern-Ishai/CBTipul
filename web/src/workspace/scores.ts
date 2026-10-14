import { score } from "../domain/questionnaires";

// Thresholds: ios/Models.swift; wording: ios/Localization.swift (GAD7/PHQ9).
export function questionnaireScore(values: readonly (number | null)[], kind: "gad" | "phq") {
  const count = kind === "gad" ? 7 : 9;
  const answered = values.filter((v) => Number.isInteger(v) && v !== null && v >= 0 && v <= 3).length;
  const total = score(values as number[], count);
  const band = total === null ? null : total < 5 ? 0 : total < 10 ? 1 : total < 15 ? 2 : kind === "gad" || total < 20 ? 3 : 4;
  const labels = kind === "gad" ? ["ללא חרדה משמעותית", "חרדה קלה", "חרדה משמעותית", "חרדה קשה"] : ["דיכאון מינימלי", "דיכאון קל", "דיכאון בינוני", "דיכאון בינוני כבד", "דיכאון כבד"];
  return { count, answered, total, label: band === null ? null : labels[band], tone: band === null ? "neutral" : band === 0 ? "good" : band === 1 || kind === "phq" && band === 2 ? "warning" : "error" };
}
