import { supabase as db } from "./client";
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
async function fn<T>(name: string, body?: object): Promise<T> {
  const r = await db.functions.invoke(name, body ? { body } : undefined);
  if (r.error) {
    let code = r.error.context?.status === 429 ? "quota" : "failed";
    try {
      const detail = await r.error.context?.json();
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
  }
}
async function guard(write = false) {
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
async function clinical(text: string, checkpoint: () => void) {
  checkpoint();
  if (!text.trim()) return "";
  if (localStorage.getItem(`cbtipul.ai.${identity}`) !== "yes")
    throw new ApiError("consent");
  const r = await fn<{ anonymizedText: string }>("anonymize-clinical-text", {
    text: scrub(text),
    therapistIdentifiers: [],
  });
  checkpoint();
  if (typeof r.anonymizedText !== "string" || !r.anonymizedText.trim()) throw new ApiError();
  return scrub(r.anonymizedText);
}
// The workspace uses the same guarded Edge Function and consent as session notes.
export async function workspaceClinicalAnonymizer(account: string) {
  const checkpoint = await guard(true);
  if (identity !== account) throw new ApiError("access");
  return async (text: string) => {
    if (identity !== account) throw new ApiError("access");
    return clinical(text, checkpoint);
  };
}
export function workspaceIdentityMatches(account: string) {
  return identity === account;
}
export function grantWorkspaceClinicalConsent(account: string) {
  if (identity !== account) throw new ApiError("access");
  localStorage.setItem(`cbtipul.ai.${account}`, "yes");
}
async function anonymizeValue(
  v: Clinical,
  checkpoint: () => void,
): Promise<Clinical> {
  checkpoint();
  if (typeof v === "string") return clinical(v, checkpoint);
  if (Array.isArray(v))
    return Promise.all(v.map((value) => anonymizeValue(value, checkpoint)));
  if (v && typeof v === "object")
    return Object.fromEntries(
      await Promise.all(
        Object.entries(v).map(async ([k, value]) => [
          k,
          k === "status" ? value : await anonymizeValue(value, checkpoint),
        ]),
      ),
    );
  return v;
}
async function rows<T>(
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
const qcols =
  "id,patient_id,session_id,created_by,answered_date,gad7_answers,phq9_answers,interference_level,combined_notes";
const scols = "id,patient_id,session_date,notes,type,structured_notes";
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
    const value = await rows<Patient>(
      "Patients",
      "id,active,notes,formulation",
    );
    done();
    return value;
  },
  async patient(id: Id) {
    const done = await guard();
    const p = unwrap(
      await db
        .from("Patients")
        .select("id,active,notes,formulation")
        .eq("id", id)
        .single(),
    ) as Patient;
    done();
    return p;
  },
  async createPatient(active: boolean) {
    const done = await guard(true);
    done();
    const p = unwrap(
      await db
        .from("Patients")
        .insert({ active })
        .select("id,active,notes,formulation")
        .single(),
    ) as Patient;
    done();
    return p;
  },
  async updatePatient(
    p: Patient,
    goal: string,
    notes: string,
    active: boolean,
  ) {
    const done = await guard(true);
    const treatmentGoal =
      goal === p.formulation?.treatmentGoal ? goal : await clinical(goal, done);
    const safeNotes = notes === p.notes ? notes : await clinical(notes, done);
    done();
    const result = unwrap(
      await db
        .from("Patients")
        .update({
          active,
          notes: safeNotes,
          formulation: { ...p.formulation, treatmentGoal },
        })
        .eq("id", p.id)
        .select("id")
        .single(),
    );
    done();
    return result;
  },
  async sessions(id?: Id) {
    const done = await guard();
    const data = await rows<Session>("Sessions", scols, id);
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
  ) {
    const done = await guard(true);
    const safe = await clinical(notes, done);
    const structured = analysis ? await anonymizeValue(analysis, done) : null;
    done();
    const payload = {
      patient_id: patientId,
      session_date: dateOnly(date),
      type: type || null,
      notes: safe,
      structured_notes: structured,
    };
    const query =
      id !== null
        ? db
            .from("Sessions")
            .update(payload)
            .eq("id", id)
            .eq("patient_id", patientId)
        : db.from("Sessions").insert(payload);
    const data = unwrap(await query.select(scols).single()) as Session;
    done();
    return data;
  },
  async questionnaires(id: Id) {
    const done = await guard();
    const data = (await rows<Questionnaire>("CombinedMood", qcols, id)).map(
      (q) => ({
        ...q,
        gad7_answers: Array.isArray(q.gad7_answers) ? q.gad7_answers : [],
        phq9_answers: Array.isArray(q.phq9_answers) ? q.phq9_answers : [],
      }),
    );
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
    const combined_notes = await anonymizeValue(
      q.combined_notes as Clinical,
      done,
    );
    done();
    const result = unwrap(
      await db
        .from("CombinedMood")
        .insert({
          patient_id,
          session_id,
          answered_date: dateOnly(q.answered_date ?? ""),
          gad7_answers,
          phq9_answers,
          interference_level,
          combined_notes,
        })
        .select("id")
        .single(),
    );
    done();
    return result as { id: Id };
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
    const system = chatContext(safeBundle(b, scrub));
    done();
    const response = await fn<{ choices: { message: { content: string } }[] }>(
      "openai-gateway",
      {
        model: "gpt-4o-mini",
        messages: [{ role: "system", content: system }, ...safeTurns],
        temperature: 0.4,
      },
    );
    done();
    const content = response.choices?.[0]?.message?.content;
    if (typeof content !== "string" || !content.trim()) throw new ApiError();
    return { content, unavailable: b.unavailable };
  },
  async analyze(notes: string) {
    const done = await guard(true);
    const sessionNotes = await clinical(notes, done);
    done();
    const r = await fn<{ analysis: Record<string, Clinical> }>(
      "analyze-session",
      { sessionNotes },
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
    if (localStorage.getItem(`cbtipul.ai.${identity}`) !== "yes")
      throw new ApiError("consent");
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
    );
    done();
    return {
      preparation: requireObject(r.preparation),
      unavailable: b.unavailable,
      generatedAt: new Date().toISOString(),
    };
  },
};
