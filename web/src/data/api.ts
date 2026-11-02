import { clinicalSave, sameClinicalValue } from "./clinical-save";
import { loadClinical } from "./clinical-load";
import { supabase as db } from "./client";
import { consents, type ConsentType } from "./consent";
import { names, therapistAllowed } from "../domain/privacy";
import {
  chatContext,
  preparationContext,
  safeBundle,
  redactClinical,
} from "../domain/context";
import type {
  AppContext,
  Assignment,
  Bundle,
  Clinical,
  Diary,
  Id,
  InboxItem,
  Patient,
  PatientMessage,
  Questionnaire,
  Session,
  ToolType,
  Turn,
} from "../domain/types";
import { score, dateOnly } from "../domain/questionnaires";
// Never expose raw backend error messages: they may include submitted clinical data.
export class ApiError extends Error {
  constructor(public code = "failed") {
    super(code);
  }
}
function unwrap<T>(r: { data: T | null; error: unknown }): NonNullable<T> {
  if (r.error || r.data === null) throw new ApiError();
  return r.data as NonNullable<T>;
}
async function fn<T>(
  name: string,
  body?: object,
  consentType?: ConsentType,
): Promise<T> {
  const caller = identity,
    callerGeneration = generation;
  const r = await db.functions.invoke(name, body ? { body } : undefined);
  if (r.error) {
    let code = r.error.context?.status === 429 ? "quota" : "failed";
    try {
      const detail = await r.error.context?.json();
      const refusal = detail?.error ?? detail?.code;
      if (
        consentType &&
        caller &&
        callerGeneration === generation &&
        refusal === "consent_required"
      ) {
        const types: ConsentType[] = [consentType];
        for (const type of types) consents.refuse(caller, type);
        await Promise.allSettled(
          types.map((type) => consents.lookup(caller, type)),
        );
        code = types.every(
          (type) =>
            consents.snapshot(caller, type).record?.status === "accepted",
        )
          ? "consent_unavailable"
          : "consent_lookup";
      }
      if (
        [
          "consent_service_unavailable",
          "consent_version_mismatch",
          "consent_registry_not_ready",
          "unsupported_consent_type",
        ].includes(refusal)
      )
        code = "consent_unavailable";
      if (
        [
          "AI_LIMIT_REACHED",
          "ai_quota_exceeded",
          "quota_exceeded",
          "AI_QUOTA_EXCEEDED",
          "THERAPIST_AI_QUOTA_EXCEEDED",
        ].includes(detail?.error ?? detail?.code)
      )
        code = "quota";
    } catch {
      /* no sensitive error logging */
    }
    throw new ApiError(code);
  }
  if (r.data === null) throw new ApiError();
  return r.data as T;
}
function requireObject(value: Record<string, Clinical>) {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new ApiError();
  return value;
}
let identity: string | null = null;
let generation = 0;
export function setApiIdentity(id: string | null) {
  if (identity !== id) {
    identity = id;
    generation++;
    consents.setAccount(id);
  }
}
export async function guard(write = false) {
  const id = identity,
    version = generation;
  const auth = await db.auth.getUser();
  if (auth.error || !auth.data.user) throw new ApiError("access");
  const user = auth.data.user;
  const context = await fn<AppContext>("get-app-context");
  if (
    id !== identity ||
    version !== generation ||
    user.id !== id ||
    !therapistAllowed(user, context)
  )
    throw new ApiError("access");
  if (write && context.entitlement?.access !== "full")
    throw new ApiError("read_only");
  return () => {
    if (id !== identity || generation !== version) throw new ApiError("stale");
  };
}
function scrub(text: string) {
  if (!identity) throw new ApiError("access");
  return names.redact(localStorage, identity, text);
}
async function clinical(
  text: string,
  checkpoint: () => void,
  consentType: ConsentType = "ai_data_sharing",
) {
  checkpoint();
  if (!text.trim()) return "";
  if (!identity) throw new ApiError("access");
  await consents.require(identity, consentType);
  checkpoint();
  const r = await fn<{ anonymizedText: string }>(
    "anonymize-clinical-text",
    {
      text: scrub(text),
      therapistIdentifiers: [],
    },
    consentType,
  );
  checkpoint();
  if (typeof r.anonymizedText !== "string" || !r.anonymizedText.trim())
    throw new ApiError();
  return scrub(r.anonymizedText);
}
// Workspace notes use the existing anonymizer and their separate consent type.
export async function workspaceClinicalAnonymizer(account: string) {
  const checkpoint = await guard(true);
  if (identity !== account) throw new ApiError("access");
  return async (text: string) => {
    if (identity !== account) throw new ApiError("access");
    return clinical(text, checkpoint, "clinical_text_processing");
  };
}
export function workspaceAccount() {
  return identity;
}
export async function refreshWorkspaceTerms(account: string) {
  consents.refuse(account, "terms_privacy");
  await consents.lookup(account, "terms_privacy").catch(() => {});
}
export function workspaceIdentityMatches(account: string) {
  return identity === account;
}
export async function rows<T>(
  table: string,
  columns: string,
  patientId?: Id,
): Promise<T[]> {
  const all: T[] = [];
  for (let offset = 0; ;) {
    let query = db
      .from(table)
      .select(columns, { count: "exact" })
      .order("id")
      .range(offset, offset + 999);
    if (patientId !== undefined) query = query.eq("patient_id", patientId);
    const response = await query;
    const page = unwrap(response) as T[];
    all.push(...page);
    offset += page.length;
    if (
      page.length === 0 ||
      (response.count !== null && offset >= response.count) ||
      (response.count === null && page.length < 1000)
    )
      break;
  }
  return all;
}

const dcols = [
  "id,patient_id,created_by,created_at,updated_at,event,automatic_thoughts,feelings,behaviour,physical_symptoms",
  "id,patient_id,created_by,created_at,updated_at,event,automatic_thoughts,feelings,thinking_errors,alternative_thoughts",
  "id,patient_id,created_by,created_at,updated_at,situation,automatic_thoughts,feelings,thinking_errors,alternative_thoughts",
];
const dtables = [
  "diary_one_entries",
  "diary_two_entries",
  "diary_three_entries",
];
export const api = {
  async profile() {
    const done = await guard();
    const data = unwrap(
      await db
        .from("therapist_profiles")
        .select("therapist_id,display_name")
        .eq("therapist_id", identity!)
        .limit(1),
    ) as { therapist_id: string; display_name: string }[];
    done();
    return data[0] ?? null;
  },
  async saveProfile(displayName: string) {
    const done = await guard(true);
    if (!displayName.trim()) throw new ApiError("invalid");
    done();
    const result = unwrap(
      await db
        .from("therapist_profiles")
        .upsert(
          { therapist_id: identity, display_name: displayName.trim() },
          { onConflict: "therapist_id" },
        )
        .select("therapist_id,display_name")
        .single(),
    );
    done();
    return result;
  },
  context: () => fn<AppContext>("get-app-context"),
  async patients() {
    const done = await guard();
    const value = await loadClinical<Patient>("load-patients", {}, done);
    done();
    return value;
  },
  async patient(id: Id) {
    const done = await guard();
    const [p] = await loadClinical<Patient>(
      "load-patients",
      { id: String(id) },
      done,
    );
    if (!p) throw new ApiError("access");
    done();
    return p;
  },
  async createPatient(active: boolean) {
    const done = await guard(true);
    return (await clinicalSave.save(
      "save-patient",
      null,
      { active },
      done,
    )) as unknown as Patient;
  },
  async updatePatient(
    p: Patient,
    goal: string,
    notes: string,
    active: boolean,
  ) {
    const done = await guard(true);

    const changes: Record<string, unknown> = { active };
    if (notes !== (p.notes ?? "")) changes.notes = notes;
    if (goal !== (p.formulation?.treatmentGoal ?? ""))
      changes.formulation = { ...p.formulation, treatmentGoal: goal };
    return clinicalSave.save("save-patient", { ...p }, changes, done);
  },
  async sessions(id?: Id) {
    const done = await guard();
    const data = await loadClinical<Session>(
      "load-sessions",
      id === undefined ? {} : { patient_id: String(id) },
      done,
    );
    done();
    return data.sort((a, b) => b.session_date.localeCompare(a.session_date));
  },
  async saveSession(
    patientId: Id,
    id: Id | null,
    date: string,
    type: string,
    notes: string,
    analysis: Record<string, Clinical> | null,
    previous?: Session,
  ) {
    const done = await guard(true);
    if (!id && !type) throw new ApiError('invalid');

    if (id && (!previous || previous.id !== id))
      throw new ApiError("record_changed");
    const changes: Record<string, unknown> = {
      session_date: dateOnly(date),
      type: type || null,
    };
    if (!id) changes.patient_id = patientId;
    if (!previous || notes !== (previous.notes ?? "")) changes.notes = notes;
    if (!sameClinicalValue(analysis, previous?.structured_notes ?? null))
      changes.structured_notes = analysis;
    return (await clinicalSave.save(
      "save-session",
      previous ? { ...previous } : null,
      changes,
      done,
    )) as unknown as Session;
  },
  async questionnaires(id: Id) {
    const done = await guard();
    const data = (
      await loadClinical<Questionnaire>(
        "load-questionnaires",
        { patient_id: String(id) },
        done,
      )
    ).map((q) => ({
      ...q,
      gad7_answers: Array.isArray(q.gad7_answers) ? q.gad7_answers : [],
      phq9_answers: Array.isArray(q.phq9_answers) ? q.phq9_answers : [],
    }));
    done();
    return data.sort((a, b) =>
      (b.answered_date ?? "").localeCompare(a.answered_date ?? ""),
    );
  },
  async saveQuestionnaire(q: Omit<Questionnaire, "id">) {
    const done = await guard(true);
    if (
      score(q.gad7_answers, 7) === null ||
      score(q.phq9_answers, 9) === null ||
      q.interference_level === null ||
      q.interference_level < 0 ||
      q.interference_level > 3
    )
      throw new ApiError("invalid");
    const {
      patient_id,
      session_id,
      gad7_answers,
      phq9_answers,
      interference_level,
    } = q;
    return (await clinicalSave.save(
      "save-questionnaire",
      null,
      {
        patient_id,
        session_id,
        answered_date: dateOnly(q.answered_date ?? ""),
        gad7_answers,
        phq9_answers,
        interference_level,
        combined_notes: q.combined_notes,
        ...(q.notes !== undefined ? { notes: q.notes } : {}),
      },
      done,
    )) as { id: Id };
  },
  async diaries(id: Id, index: number) {
    const done = await guard();
    if (index < 0 || index > 2) throw new ApiError();
    const data = await rows<Diary>(dtables[index], dcols[index], id);
    done();
    return data.sort((a, b) => b.created_at.localeCompare(a.created_at));
  },
  async assignments(id: Id) {
    const done = await guard();
    const data = await rows<Assignment>(
      "patient_assignments",
      "id,patient_id,type,session_id,cancelled_at,created_at",
      id,
    );
    done();
    return data;
  },
  async connected(id: Id) {
    const done = await guard();
    const value = unwrap(
      await db.rpc("is_patient_connected", { p_patient_id: String(id) }),
    );
    done();
    return value === true;
  },
  async activate(id: Id, type: ToolType) {
    const done = await guard(true);
    if (!(await api.connected(id))) throw new ApiError("disconnected");
    done();
    const endpoint = {
      questionnaire: "request-patient-questionnaire",
      diary_1: "request-patient-diary-one",
      diary_2: "request-patient-diary-two",
      diary_3: "request-patient-diary-three",
    }[type];
    await fn(endpoint, { patientId: String(id) });
    done();
    const active = (await api.assignments(id)).find(
      (a) =>
        a.type === type && a.session_id === null && a.cancelled_at === null,
    );
    if (!active) throw new ApiError();
    return active;
  },
  async deactivate(id: string) {
    const done = await guard(true);
    const r = unwrap(
      await db
        .from("patient_assignments")
        .update({ cancelled_at: new Date().toISOString() })
        .eq("id", id)
        .is("cancelled_at", null)
        .select("id")
        .single(),
    );
    done();
    return r;
  },
  async messages(id: Id) {
    const done = await guard();
    const data = await rows<PatientMessage>(
      "patient_messages",
      "id,patient_id,body,created_at,read_at",
      id,
    );
    done();
    return data.sort((a, b) => b.created_at.localeCompare(a.created_at));
  },
  async sendMessage(id: Id, body: string) {
    const done = await guard(true);
    if (!body.trim() || body.trim().length > 4000)
      throw new ApiError("invalid");
    done();
    const r = await fn<{ success?: boolean }>("send-patient-message", {
      patientId: String(id),
      body: scrub(body.trim()),
    });
    if (r.success === false) throw new ApiError();
    done();
  },
  async notifications() {
    const done = await guard();
    const data = unwrap(
      await db
        .from("notifications")
        .select(
          "id,type,patient_id,session_id,assignment_id,resource_type,resource_id,created_at,seen_at,read_at",
        )
        .eq("recipient_user_id", identity!)
        .order("created_at", { ascending: false }),
    ) as InboxItem[];
    done();
    return data;
  },
  async seen() {
    const done = await guard();
    const r = await db.rpc("mark_notifications_seen");
    if (r.error) throw new ApiError();
    done();
  },
  async read(id: string) {
    const done = await guard();
    const r = await db.rpc("mark_notification_read", { p_notification_id: id });
    if (r.error) throw new ApiError();
    done();
  },
  async bundle(id: Id): Promise<Bundle> {
    const patient = await api.patient(id);
    const unavailable: string[] = [];
    async function best<T>(name: string, p: Promise<T[]>) {
      try {
        return await p;
      } catch (e) {
        if (e instanceof ApiError && ["access", "stale"].includes(e.code))
          throw e;
        unavailable.push(name);
        return [] as T[];
      }
    }
    const [sessions, questionnaires, ...diaries] = await Promise.all([
      best("sessions", api.sessions(id)),
      best("questionnaires", api.questionnaires(id)),
      ...dtables.map((_, i) => best(`diary_${i + 1}`, api.diaries(id, i))),
    ]);
    return {
      patient,
      sessions: sessions as Session[],
      questionnaires: questionnaires as Questionnaire[],
      diaries: diaries as Diary[][],
      unavailable,
    };
  },
  async chat(id: Id, turns: Turn[]) {
    const done = await guard(true);
    const b = await api.bundle(id);
    const safeTurns = await Promise.all(
      turns.map(async (t) => ({
        ...t,
        content:
          t.role === "user"
            ? await clinical(t.content, done)
            : scrub(t.content),
      })),
    );
    await consents.require(identity!, "ai_data_sharing");
    const system = chatContext(safeBundle(b, scrub));
    done();
    const response = await fn<{ choices: { message: { content: string } }[] }>(
      "openai-gateway",
      {
        model: "gpt-4o-mini",
        messages: [{ role: "system", content: system }, ...safeTurns],
        temperature: 0.4,
      },
      "ai_data_sharing",
    );
    done();
    const content = response.choices?.[0]?.message?.content;
    if (typeof content !== "string" || !content.trim()) throw new ApiError();
    return { content, unavailable: b.unavailable };
  },
  async analyze(notes: string) {
    const done = await guard(true);
    const sessionNotes = await clinical(notes, done);
    await consents.require(identity!, "ai_data_sharing");
    done();
    const r = await fn<{ analysis: Record<string, Clinical> }>(
      "analyze-session",
      { sessionNotes },
      "ai_data_sharing",
    );
    done();
    if (
      !r.analysis ||
      typeof r.analysis !== "object" ||
      Array.isArray(r.analysis)
    )
      throw new ApiError();
    return r.analysis;
  },
  async prepare(id: Id) {
    const done = await guard(true);
    if (!identity) throw new ApiError("access");
    await consents.require(identity, "ai_data_sharing");
    done();
    const b = await api.bundle(id);
    const patientContext = preparationContext(safeBundle(b, scrub));
    const latest = b.sessions.filter(
      (s) =>
        s.session_date.slice(0, 10) <= new Date().toISOString().slice(0, 10),
    )[0];
    done();
    const r = await fn<{ preparation: Record<string, Clinical> }>(
      "prepare-session",
      {
        patientContext,
        lastSessionAssignments: redactClinical(
          latest?.structured_notes?.assignments_for_next_week ?? null,
          scrub,
        ),
      },
      "ai_data_sharing",
    );
    done();
    return {
      preparation: requireObject(r.preparation),
      unavailable: b.unavailable,
      generatedAt: new Date().toISOString(),
    };
  },
};
