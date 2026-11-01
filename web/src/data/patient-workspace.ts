import { supabase as db } from './client';
import { ApiError, guard, rows, workspaceAccount, workspaceClinicalAnonymizer } from './api';
import { dateOnly } from '../domain/questionnaires';
import { consents } from './consent';
import { isFormComplete, type Worksheet } from '../workspace/model';

export const canonical = (id: string) => id.toLowerCase();
export const questionnaireColumns = 'id::text,patient_id,session_id::text,created_by,answered_date,gad7_answers,phq9_answers,interference_level';
export const diaryFields = {
  diary_one: ['event','automatic_thoughts','feelings','behaviour','physical_symptoms'],
  diary_two: ['event','automatic_thoughts','feelings','thinking_errors','alternative_thoughts'],
  diary_three: ['situation','automatic_thoughts','feelings','thinking_errors','alternative_thoughts'],
} as const;
export type RecordRow = Record<string, unknown> & { id: string; patient_id: string };
export type NameRow = { patient_id: string; name: string | null; revision: string; updated_at: string | null };
export function decodeNamePage(value: unknown): { names: NameRow[]; next_after: string | null } {
  const p = value as {names?: NameRow[]; next_after?: string | null};
  if (!p || !Array.isArray(p.names) || !(p.next_after === null || typeof p.next_after === 'string') || p.names.some(n => typeof n.patient_id !== 'string' || !(n.name === null || typeof n.name === 'string') || typeof n.revision !== 'string' || !/^\d+$/.test(n.revision) || !(n.updated_at === null || typeof n.updated_at === 'string'))) throw new ApiError('invalid_response');
  return { names: p.names.map(n => ({...n, patient_id: canonical(n.patient_id)})), next_after: p.next_after };
}
export async function patientNames(account: string) {
  const done = await guard();
  await consents.require(account, 'patient_name_storage'); done();
  const result: Record<string,string> = {}, seen = new Set<string>();
  let after: string | null = null;
  do {
    const response = await db.functions.invoke('patient-names', { body: { operation:'list', after, limit:100 } });
    done();
    if (response.error) {
      let code = 'names_unavailable';
      try { const detail = await response.error.context?.json(); if (detail?.code === 'consent_required' || detail?.error === 'consent_required') { consents.refuse(account,'patient_name_storage'); code='consent'; } } catch { /* no bodies in diagnostics */ }
      throw new ApiError(code);
    }
    const page = decodeNamePage(response.data);
    page.names.forEach(n => { if (n.name) result[n.patient_id] = n.name; });
    after = page.next_after;
    if (after && seen.has(after)) throw new ApiError('invalid_response');
    if (after) seen.add(after);
  } while (after);
  return result;
}
export async function patientDirectory() {
  const done = await guard();
  const value = await rows<{id:string;active:boolean}>('Patients','id,active'); done(); return value;
}
export async function verifyPatient(patient: string) {
  const done = await guard();
  const response = await db.from('Patients').select('id').eq('id',patient).single(); done();
  if (response.error || !response.data || canonical(response.data.id) !== canonical(patient)) throw new ApiError('access');
  return true;
}
export function columns(type: Worksheet['type'], shared: boolean) {
  return type === 'questionnaire' ? questionnaireColumns + (shared ? '' : ',combined_notes') : ['id','patient_id','created_by','created_at','updated_at', ...diaryFields[type]].join(',');
}
const table = (type: Worksheet['type']) => type === 'questionnaire' ? 'CombinedMood' : `${type}_entries`;
export async function recordHistory(patient: string, type: Worksheet['type'], shared: boolean) {
  const done = await guard();
  const value = await rows<RecordRow>(table(type),columns(type,shared),patient); done();
  return value.sort((a,b) => String(b.created_at ?? b.answered_date ?? '').localeCompare(String(a.created_at ?? a.answered_date ?? '')));
}
export function editableContent(item: Worksheet) {
  if (!isFormComplete(item)) throw new ApiError('invalid');
  if (item.type === 'questionnaire') return {answered_date:item.measurement_date,gad7_answers:item.data.gad7_answers,phq9_answers:item.data.phq9_answers,interference_level:item.data.interference_level};
  return Object.fromEntries(diaryFields[item.type].filter(k => item.data[k] !== undefined).map(k => [k,item.data[k]]));
}
// Only the INSERT/UPDATE boundary can produce an uncertain-create result.
// Processing/validation failures before this point remain safely retryable.
export async function writeRecord(tableName: string, patient: string, id: string | null, content: Record<string,unknown>, selection: string, done: () => void, creation: Record<string,unknown> = {}) {
  done();
  let response;
  try {
    const query = id ? db.from(tableName).update(content).eq('id',id).eq('patient_id',patient) : db.from(tableName).insert({...content,...creation,patient_id:patient});
    response = await query.select(selection).single();
  } catch { throw new ApiError(id ? 'failed' : 'uncertain_create'); }
  done();
  if (response.error) {
    const code = response.error.code ?? '';
    const known = /^(22|23|28|42|P0001|PGRST)/.test(code);
    throw new ApiError(!id && !known ? 'uncertain_create' : code === '42501' ? 'access' : 'failed');
  }
  const row = response.data as unknown as RecordRow | null;
  if (!row || !row.id || canonical(String(row.patient_id)) !== canonical(patient) || (id && String(row.id) !== id)) throw new ApiError(id ? 'failed' : 'uncertain_create');
  return row;
}
export async function saveRecord(patient: string, id: string | null, item: Worksheet, shared: boolean, sessionId: string | null, notes?: unknown) {
  const done = await guard(true), content = editableContent(item);
  if (item.type === 'questionnaire') {
    // Shared writes intentionally omit combined_notes even when an untrusted caller supplies it.
    if (!shared && notes !== undefined) {
      const anonymize = await workspaceClinicalAnonymizer(workspaceAccount()!);
      async function scrub(v: unknown): Promise<unknown> {
        if (typeof v === 'string') return v.trim() ? anonymize(v) : v;
        if (Array.isArray(v)) return Promise.all(v.map(scrub));
        if (v && typeof v === 'object') return Object.fromEntries(await Promise.all(Object.entries(v).map(async ([k,x]) => [k, await scrub(x)])));
        return v;
      }
      Object.assign(content,{combined_notes: await scrub(notes)});
    }
    if (!id) Object.assign(content,{session_id:sessionId});
  }
  return writeRecord(table(item.type),patient,id,content,columns(item.type,shared),done,item.type === 'questionnaire' ? {} : {therapist_id:workspaceAccount(),created_by:'therapist'});
}
export async function savePatientSession(patient: string,id: string|null,date: string,type: string,notes: string, previous?: string) {
  const done = await guard(true);
  const safe = notes === previous ? notes : await (await workspaceClinicalAnonymizer(workspaceAccount()!))(notes);
  const content: Record<string,unknown> = {session_date:dateOnly(date),type:type || null,notes:safe};
  if (notes !== previous) content.structured_notes = null;
  return writeRecord('Sessions',patient,id,content,'id::text,patient_id,session_date,type,notes,structured_notes',done);
}
