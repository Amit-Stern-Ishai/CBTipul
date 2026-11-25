import { supabase } from "./client";
import { guard, workspaceAccount, ApiError } from "./api";
export interface ExposureItem {
  id: string;
  situation: string;
  difficulty: number | null;
}
export interface ExposureDocument {
  items: ExposureItem[];
}
export interface ExposureRecord {
  patient_id: string;
  document: ExposureDocument | null;
  revision: string | null;
  updated_at: string | null;
}
export const emptyExposure = (): ExposureDocument => ({ items: [] });
export function validExposure(v: ExposureDocument): boolean {
  const ids = new Set<string>();
  return (
    v.items.length <= 100 &&
    v.items.every((x) => {
      const id = x.id.toLowerCase();
      if (ids.has(id)) return false;
      ids.add(id);
      return (
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          id,
        ) &&
        typeof x.situation === "string" &&
        !!x.situation.trim() &&
        Array.from(x.situation).length <= 1000 &&
        (x.difficulty === null ||
          (Number.isInteger(x.difficulty) &&
            x.difficulty >= 0 &&
            x.difficulty <= 100))
      );
    })
  );
}
export function moveExposure(
  d: ExposureDocument,
  id: string,
  to: number,
): ExposureDocument {
  const from = d.items.findIndex((x) => x.id === id);
  if (from < 0 || to < 0 || to >= d.items.length) return d;
  const items = [...d.items];
  items.splice(to, 0, items.splice(from, 1)[0]);
  return { items };
}
export function exposureBody(
  action: "load" | "save",
  patient: string | null,
  revision: string | null,
  document: ExposureDocument,
) {
  if (action === "save" && !validExposure(document))
    throw new ApiError("invalid");
  return {
    action,
    ...(patient ? { patient_id: patient } : {}),
    ...(action === "save"
      ? {
          expected_revision: revision,
          document: { items: document.items.map((x) => ({ ...x })) },
        }
      : {}),
  };
}
export async function exposureRequest(
  action: "load" | "save",
  patient: string,
  revision: string | null,
  document: ExposureDocument,
): Promise<ExposureRecord> {
  const owner = workspaceAccount(),
    done = await guard(action === "save");
  const { data, error } = await supabase.functions.invoke(
    "patient-exposure-hierarchy",
    { body: exposureBody(action, patient, revision, document) },
  );
  done();
  if (owner !== workspaceAccount()) throw new ApiError("stale");
  if (error) {
    let code = "failed";
    try {
      const body = await error.context?.json();
      if (error.context?.status === 409 && body?.error === "revision_conflict")
        code = "revision_conflict";
      else if ([401, 403].includes(error.context?.status)) code = "access";
    } catch {
      /* no content logging */
    }
    throw new ApiError(code);
  }
  if (
    !data ||
    typeof data.patient_id !== "string" ||
    data.patient_id.toLowerCase() !== patient.toLowerCase() ||
    (data.document !== null &&
      (!Array.isArray(data.document?.items) ||
        !validExposure(data.document) ||
        typeof data.revision !== "string" ||
        !data.revision))
  )
    throw new ApiError("failed");
  return data;
}
