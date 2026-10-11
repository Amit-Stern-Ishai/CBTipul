import { he } from "../he";
import { unsaved } from "../domain/dirty";
import { useEffect, type ReactNode } from "react";
import { useBlocker } from "react-router-dom";
import {
  LoaderCircle,
  AlertCircle,
  ArrowRight,
  FileText,
  Activity,
  BookOpen,
  Bell,
  MessageCircle,
  UserRound,
  CalendarDays,
  Sparkles,
} from "lucide-react";
import mobile from "../mobile-he.json";
import type { Clinical } from "../domain/types";
import { ApiError } from "../data/api";
export const icons = {
  patients: UserRound,
  sessions: CalendarDays,
  questionnaire: Activity,
  diary: BookOpen,
  notifications: Bell,
  message: MessageCircle,
  ai: Sparkles,
};
export const date = (s: string | null | undefined) => {
  if (!s) return he.shared001;
  const parsed = new Date(s.length === 10 ? s + "T12:00:00" : s);
  return Number.isNaN(parsed.getTime())
    ? he.shared001
    : new Intl.DateTimeFormat("he-IL", {
        year: "numeric",
        month: "short",
        day: "numeric",
      }).format(parsed);
};
export const today = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
};
export function Loading() {
  return (
    <div className="state" role="status">
      <LoaderCircle className="spin" />
      {he.shared002}
    </div>
  );
}
export function Empty({ children }: { children: ReactNode }) {
  return (
    <div className="state">
      <FileText />
      <p>{children}</p>
    </div>
  );
}
export function ErrorBox({
  error,
  retry,
}: {
  error: unknown;
  retry?: () => void;
}) {
  const c = error instanceof ApiError ? error.code : "";
  const msg: Record<string, string> = {
    quota: he.shared003,
    read_only: he.shared004,
    consent: he.shared005,
    disconnected: he.shared006,
    access: he.shared007,
    invalid: he.shared008,
  };
  return (
    <div role="alert" className="error">
      <AlertCircle size={20} />
      <span>{msg[c] ?? he.shared009}</span>
      {retry && (
        <button className="text-button" onClick={retry}>
          {he.shared010}
        </button>
      )}
    </div>
  );
}
export function Heading({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <header className="page-heading">
      <div>
        <h1>{title}</h1>
        {description && <p>{description}</p>}
      </div>
      {action}
    </header>
  );
}
export function DirtyGuard({ dirty }: { dirty: boolean }) {
  useEffect(() => {
    unsaved.active = dirty;
    return () => {
      unsaved.active = false;
    };
  }, [dirty]);
  const blocker = useBlocker(dirty);
  useEffect(() => {
    const f = (e: BeforeUnloadEvent) => {
      if (dirty) {
        e.preventDefault();
        e.returnValue = "";
      }
    };
    window.addEventListener("beforeunload", f);
    return () => window.removeEventListener("beforeunload", f);
  }, [dirty]);
  if (blocker.state !== "blocked") return null;
  return (
    <div className="modal-backdrop">
      <section
        onKeyDown={(e) => {
          if (e.key === "Escape") {
            e.preventDefault();
            blocker.reset();
          }
          if (e.key === "Tab") {
            const buttons =
              e.currentTarget.querySelectorAll<HTMLButtonElement>("button");
            const first = buttons[0],
              last = buttons[buttons.length - 1];
            if (e.shiftKey && document.activeElement === first) {
              e.preventDefault();
              last.focus();
            } else if (!e.shiftKey && document.activeElement === last) {
              e.preventDefault();
              first.focus();
            }
          }
        }}
        role="dialog"
        aria-modal="true"
        aria-labelledby="dirty-title"
        className="modal"
      >
        <h2 id="dirty-title">{he.shared011}</h2>
        <p>{he.shared012}</p>
        <div className="actions">
          <button autoFocus onClick={() => blocker.reset()}>
            {he.shared013}
          </button>
          <button className="secondary" onClick={() => blocker.proceed()}>
            {he.shared014}
          </button>
        </div>
      </section>
    </div>
  );
}
const fieldNames: Record<string, string> = {
  session_summary: he.Sessions012,
  key_situations: he.shared015,
  possible_nats: he.shared016,
  cbt_cycles: he.shared017,
  therapist_hypotheses: he.shared018,
  follow_up_questions: he.shared019,
  assignments_for_next_week: he.shared020,
  executive_summary: he.shared021,
  priority_follow_ups: he.shared022,
  recurring_nats: he.shared023,
  questionnaire_insights: he.shared024,
  treatment_focus: he.shared025,
  suggested_questions: he.shared026,
  core_belief_hypothesis: he.shared027,
  assignments_to_check: he.shared028,
  thought: he.shared029,
  situation: he.shared030,
  emotion: he.shared031,
  behavior: he.Diaries018,
  evidence: he.shared032,
  confidence: he.shared033,
  hypothesis: he.shared034,
  question: he.Questionnaires020,
  reason: he.shared035,
  assignment: he.shared036,
  details: he.shared037,
  item: he.shared038,
  source: he.shared039,
  focus: he.shared040,
  rationale: he.shared041,
  purpose: he.shared042,
  priority: he.shared043,
  belief: he.shared044,
  observation: he.shared045,
  clinical_relevance: he.shared046,
  situations: he.shared047,
  cognitive_patterns: he.Diaries020,
  pattern: he.shared048,
  why_it_matters: he.shared049,
  trigger_situation: he.shared050,
  automatic_thought: he.shared051,
  short_term_consequence: he.shared052,
  long_term_consequence: he.shared053,
  text: he.shared054,
  name: he.shared031,
  intensity: he.shared055,
  beliefBefore: he.shared056,
  beliefAfter: he.shared057,
  intensityBefore: he.shared058,
  intensityAfter: he.shared059,
  code: he.shared060,
};
export function ClinicalContent({ value }: { value: Clinical | undefined }) {
  if (value === null || value === undefined || value === "") return null;
  if (Array.isArray(value))
    return (
      <ul className="clinical-list">
        {value.map((v, i) => (
          <li key={i}>
            <ClinicalContent value={v} />
          </li>
        ))}
      </ul>
    );
  if (typeof value === "object")
    return (
      <div className="clinical-fields">
        {Object.entries(value)
          .filter(([k]) => k !== "status")
          .map(([k, v]) => (
            <div key={k}>
              <strong>{fieldNames[k] ?? he.shared037}</strong>
              <ClinicalContent
                value={
                  typeof v === "number" && /^(intensity|belief)/.test(k)
                    ? `${v}%`
                    : v
                }
              />
            </div>
          ))}
      </div>
    );
  return (
    <p className="prose">
      {typeof value === "string"
        ? ((mobile as Record<string, string | string[]>)[
            `thinking_error_${value}`
          ] ?? value)
        : String(value)}
    </p>
  );
}
export function Back({ onClick }: { onClick: () => void }) {
  return (
    <button className="text-button" onClick={onClick}>
      <ArrowRight size={17} />
      {he.shared061}
    </button>
  );
}
