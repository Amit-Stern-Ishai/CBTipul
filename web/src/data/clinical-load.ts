import { supabase } from './client';
// Fixed clinical load endpoints only. No query language or write adapter.
export type ClinicalEndpoint = 'load-patients' | 'load-sessions' | 'load-questionnaires';
export async function loadClinical<T>(endpoint: ClinicalEndpoint, params: {id?: string; patient_id?: string; view?: 'shared'} = {}, checkpoint: () => void = () => {}) : Promise<T[]> {
  const records: T[] = [], seen = new Set<string>();
  const ids = new Set<string>();
  let cursor: string | null = null;
  do {
    checkpoint();
    const {data, error}: {data: {records: Record<string, unknown>[]; next_cursor: string | null} | null; error: unknown} = await supabase.functions.invoke(endpoint, {body: {...params, limit:100, ...(cursor ? {cursor} : {})}});
    checkpoint();
    if (error) throw error;
    if (!data || !Array.isArray(data.records) || !(data.next_cursor === null || typeof data.next_cursor === 'string' && data.next_cursor.length > 0)) throw new Error('invalid_clinical_response');
    for (const row of data.records) {
      if (!row || typeof row.id !== 'string' || typeof row._version !== 'string' || !row._version || ['patient_id','session_id','therapist_id','assignment_id'].some(k => row[k] != null && typeof row[k] !== 'string') || (params.id && row.id !== params.id) || (params.patient_id && row.patient_id !== params.patient_id)) throw new Error('invalid_clinical_record');
      // Fail closed if a shared response ever contains private fields.
      if (params.view === 'shared' && ('notes' in row || 'combined_notes' in row)) throw new Error('private_clinical_response');
      if (ids.has(row.id)) throw new Error('duplicate_clinical_record');
      ids.add(row.id);
      records.push(row as T);
    }
    cursor = data.next_cursor;
    if (cursor && (params.id || seen.has(cursor))) throw new Error('invalid_clinical_cursor');
    if (cursor) seen.add(cursor);
  } while (cursor !== null);
  return records;
}
