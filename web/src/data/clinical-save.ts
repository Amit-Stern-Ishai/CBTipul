import { supabase } from "./client";
import { ApiError } from "./api";
export type SaveEndpoint =
  "save-patient" | "save-session" | "save-questionnaire";
type Row = Record<string, unknown>;
function stable(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([k, v]) => [k, stable(v)]),
    );
  return value;
}
export const sameClinicalValue = (a: unknown, b: unknown) =>
  JSON.stringify(stable(a)) === JSON.stringify(stable(b));
export class ClinicalSave {
  constructor(
    private invoke = (endpoint: SaveEndpoint, body: Row) =>
      supabase.functions.invoke(endpoint, { body }),
  ) {}
  async save(
    endpoint: SaveEndpoint,
    previous: Row | null,
    proposed: Row,
    checkpoint: () => void,
    shared = false,
  ): Promise<Row> {
    checkpoint();
    if (
      previous &&
      (typeof previous.id !== "string" ||
        typeof previous._version !== "string" ||
        !previous._version)
    )
      throw new ApiError("record_changed");
    const changes = Object.fromEntries(
      Object.entries(proposed).filter(
        ([key, value]) =>
          value !== undefined &&
          !(shared && ["notes", "combined_notes"].includes(key)) &&
          (!previous || !sameClinicalValue(previous[key], value)),
      ),
    );
    if (previous) delete changes.patient_id;
    const body = {
      mode: previous ? "update" : "create",
      ...(previous
        ? { id: previous.id, expected_version: previous._version }
        : {}),
      changes,
      ...(shared ? { view: "shared" } : {}),
    };
    let response;
    try {
      response = await this.invoke(endpoint, body);
    } catch {
      checkpoint();
      throw new ApiError(
        previous ? "save_outcome_unknown" : "uncertain_create",
      );
    }
    checkpoint();
    if (response.error) {
      let code = "failed";
      try {
        const detail = await response.error.context?.json();
        code = detail?.code ?? detail?.error ?? code;
      } catch {
        /* fixed errors only */
      }
      if (
        ["save_outcome_unknown", "save_not_confirmed"].includes(code) ||
        (code !== "record_changed" &&
          (!response.error.context?.status ||
            response.error.context.status === 408 ||
            response.error.context.status >= 500))
      )
        throw new ApiError(
          previous ? "save_outcome_unknown" : "uncertain_create",
        );
      throw new ApiError(
        code === "record_changed"
          ? "record_changed"
          : response.error.context?.status === 403
            ? "access"
            : "failed",
      );
    }
    const row = response.data?.record;
    if (
      !row ||
      typeof row.id !== "string" ||
      typeof row._version !== "string" ||
      !row._version ||
      (previous && row.id !== previous.id) ||
      (proposed.patient_id && row.patient_id !== proposed.patient_id) ||
      (shared && ("notes" in row || "combined_notes" in row))
    )
      throw new ApiError(
        previous ? "save_outcome_unknown" : "uncertain_create",
      );
    return row;
  }
}
export const clinicalSave = new ClinicalSave();
