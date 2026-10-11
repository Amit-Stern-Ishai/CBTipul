export type Id = string | number;
export type Clinical =
  string | number | boolean | null | Clinical[] | { [key: string]: Clinical };
export interface Patient {
  id: Id;
  active: boolean | null;
  notes: string | null;
  formulation: Record<string, Clinical> | null;
}
export interface Session {
  id: Id;
  patient_id: Id;
  session_date: string;
  notes: string | null;
  type: string | null;
  structured_notes: Record<string, Clinical> | null;
}
export interface Questionnaire {
  id: Id;
  patient_id: Id;
  session_id: Id | null;
  answered_date: string | null;
  created_at?: string;
  created_by: string | null;
  gad7_answers: number[];
  phq9_answers: number[];
  interference_level: number | null;
  combined_notes: {
    gad7: string[];
    phq9: string[];
    interference: string;
  } | null;
}
export interface Diary {
  id: string;
  patient_id: Id;
  created_by: string;
  created_at: string;
  updated_at: string;
  event?: string;
  situation?: string;
  automatic_thoughts: Clinical[];
  feelings: Clinical[];
  behaviour?: string;
  physical_symptoms?: string | null;
  thinking_errors?: Clinical[];
  alternative_thoughts?: Clinical[];
}
export type ToolType = "questionnaire" | "diary_1" | "diary_2" | "diary_3";
export interface Assignment {
  id: string;
  patient_id: Id;
  type: ToolType;
  session_id: Id | null;
  cancelled_at: string | null;
  created_at: string;
}
export interface InboxItem {
  id: string;
  type: string;
  patient_id: Id | null;
  session_id: Id | null;
  assignment_id: string | null;
  resource_type: string | null;
  resource_id: string | null;
  created_at: string;
  read_at: string | null;
  seen_at: string | null;
}
export interface PatientMessage {
  id: string;
  patient_id: Id;
  body: string;
  created_at: string;
  read_at: string | null;
}
export interface AppContext {
  role: "therapist" | "patient";
  entitlement?: { access: "full" | "read_only" } | null;
}
export interface Bundle {
  patient: Patient;
  sessions: Session[];
  questionnaires: Questionnaire[];
  diaries: Diary[][];
  unavailable: string[];
}
export interface Turn {
  role: "user" | "assistant";
  content: string;
}
