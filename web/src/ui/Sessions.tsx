import { he } from "../he";
import { useState, type FormEvent } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { CalendarDays, Plus, Sparkles } from "lucide-react";
import { api } from "../data/api";
import { useAuth } from "../auth/Auth";
import { names } from "../domain/privacy";
import type { Session, Clinical } from "../domain/types";
import { useAction, usePatients, useWrite } from "./hooks";
import {
  Heading,
  Loading,
  ErrorBox,
  Empty,
  DirtyGuard,
  date,
  today,
  ClinicalContent,
} from "./shared";
import { PatientBreadcrumb } from "./Patients";
import mobile from "../mobile-he.json";
import { useReadOnDisplay } from "./App";
const types = [
  "first_phone_call",
  "intake",
  "psycho_education",
  "diary_one",
  "diary_two",
  "diary_three",
  "case_formulation",
  "behavioral_interventions",
  "relapse_prevention_and_termination",
];
function typeLabel(type: string) {
  return (
    ((mobile as Record<string, string | string[]>)[
      `session_type_${type}`
    ] as string) || he.Sessions001
  );
}
export function SessionsPage() {
  const { patientId: id } = useParams(),
    { session } = useAuth();
  const rows = useQuery({
    queryKey: [session!.user.id, "sessions", id],
    queryFn: () => api.sessions(id),
  });
  const patients = usePatients(),
    write = useWrite();
  const [pick, setPick] = useState("");
  return (
    <>
      {id && <PatientBreadcrumb id={id} title={he.App009} />}
      <Heading
        title={he.App009}
        description={he.Sessions002}
        action={
          write &&
          id && (
            <Link className="button" to={`/patients/${id}/sessions/new`}>
              <Plus size={18} />
              {he.Sessions003}
            </Link>
          )
        }
      />
      {!id && write && (
        <div className="toolbar">
          <label>
            {he.Sessions004}
            <select value={pick} onChange={(e) => setPick(e.target.value)}>
              <option value="">{he.Sessions005}</option>
              {patients.data?.map((p) => (
                <option key={p.id} value={p.id}>
                  {names.get(localStorage, session!.user.id, p.id) ||
                    he.Sessions006(String(p.id).slice(0, 8))}
                </option>
              ))}
            </select>
          </label>
          {pick && (
            <Link className="button" to={`/patients/${pick}/sessions/new`}>
              {he.Sessions007}
            </Link>
          )}
        </div>
      )}
      {rows.isPending ? (
        <Loading />
      ) : rows.isError ? (
        <ErrorBox error={rows.error} />
      ) : rows.data.length ? (
        <div className="list panel">
          {rows.data.map((s) => (
            <Link
              className="list-row"
              key={s.id}
              to={`/patients/${s.patient_id}/sessions/${s.id}`}
            >
              <span className="icon-tile">
                <CalendarDays />
              </span>
              <div>
                <strong>
                  {id
                    ? date(s.session_date)
                    : names.get(localStorage, session!.user.id, s.patient_id) ||
                      he.Ai004}
                </strong>
                <p>
                  {!id && `${date(s.session_date)} · `}
                  {s.type ? typeLabel(s.type) : he.Sessions001}
                </p>
                <p className="clamp">{s.notes || he.Sessions008}</p>
              </div>
            </Link>
          ))}
        </div>
      ) : (
        <Empty>{he.Sessions009}</Empty>
      )}
    </>
  );
}
export function SessionEditor() {
  const { patientId: id = "", sessionId: sid = "" } = useParams(),
    { session } = useAuth();
  const rows = useQuery({
    queryKey: [session!.user.id, "sessions", id],
    queryFn: () => api.sessions(id),
    enabled: sid !== "new",
  });
  if (sid !== "new" && rows.isPending) return <Loading />;
  if (rows.isError && !rows.data) return <ErrorBox error={rows.error} />;
  const existing = rows.data?.find((s) => String(s.id) === sid);
  if (sid !== "new" && !existing) return <Empty>{he.Sessions010}</Empty>;
  return <Editor key={sid} id={id} original={existing} />;
}
function Editor({ id, original: s }: { id: string; original?: Session }) {
  const write = useWrite(),
    navigate = useNavigate();
  const [notes, setNotes] = useState(s?.notes ?? ""),
    [day, setDay] = useState(s?.session_date.slice(0, 10) ?? today()),
    [type, setType] = useState(s?.type ?? ""),
    [analysis, setAnalysis] = useState<Record<string, Clinical> | null>(
      s?.structured_notes ?? null,
    ),
    [saved, setSaved] = useState(false);
  const dirty =
    !saved &&
    (notes !== (s?.notes ?? "") ||
      day !== (s?.session_date.slice(0, 10) ?? today()) ||
      type !== (s?.type ?? "") ||
      (analysis !== s?.structured_notes && analysis !== null));
  useReadOnDisplay(!!s);
  const save = useAction(() =>
    api.saveSession(id, s?.id ?? null, day, type, notes, analysis),
  );
  const ai = useAction(() => api.analyze(notes));
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (save.isPending) return;
    try {
      const result = await save.mutateAsync();
      setSaved(true);
      setTimeout(
        () =>
          navigate(`/patients/${id}/sessions/${result.id}`, { replace: true }),
        0,
      );
    } catch {
      /* inline */
    }
  }
  return (
    <>
      <PatientBreadcrumb id={id} title={s ? he.Sessions011 : he.Sessions003} />
      <Heading title={s ? he.Sessions012 : he.Sessions003} />
      <DirtyGuard dirty={dirty} />
      <form onSubmit={submit} className="panel">
        <fieldset disabled={!write || save.isPending}>
          <div className="form-row">
            <label>
              {he.Sessions013}
              <input
                type="date"
                required
                value={day}
                onChange={(e) => {
                  setDay(e.target.value);
                  setSaved(false);
                }}
              />
            </label>
            <label>
              {he.Sessions014}
              <select
                value={type}
                onChange={(e) => {
                  setType(e.target.value);
                  setSaved(false);
                }}
              >
                <option value="">{he.Sessions015}</option>
                {types.map((t) => (
                  <option key={t} value={t}>
                    {typeLabel(t)}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <label>
            {he.Sessions012}
            <textarea
              aria-label={he.Sessions012}
              className="session-editor"
              placeholder={he.Sessions016}
              value={notes}
              onChange={(e) => {
                setNotes(e.target.value);
                setSaved(false);
              }}
            />
          </label>
        </fieldset>
        <div className="editor-footer">
          <p className="muted">{he.Sessions017}</p>
          <button disabled={!write || save.isPending || (!dirty && !!s)}>
            {save.isPending ? he.Patients041 : he.Sessions018}
          </button>
        </div>
        {saved && (
          <p role="status" className="success">
            {he.Sessions019}
          </p>
        )}
        {save.isError && <ErrorBox error={save.error} />}
      </form>
      <section className="panel ai-panel">
        <div className="section-heading">
          <div>
            <h2>
              <Sparkles size={20} />
              {he.Sessions020}
            </h2>
            <p>{he.Sessions021}</p>
          </div>
          <button
            className="secondary"
            disabled={!write || !notes.trim() || ai.isPending || save.isPending}
            onClick={async () => {
              try {
                setAnalysis(await ai.mutateAsync());
                setSaved(false);
              } catch {
                /* inline */
              }
            }}
          >
            {ai.isPending
              ? he.Sessions022
              : analysis
                ? he.Sessions023
                : he.Sessions024}
          </button>
        </div>
        {ai.isError && <ErrorBox error={ai.error} />}
        <ClinicalContent value={analysis} />
        {analysis && <p className="small">{he.Sessions025}</p>}
      </section>
    </>
  );
}
