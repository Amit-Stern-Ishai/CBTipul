import { he } from "../he";
import { useState, useRef, type FormEvent } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useQuery, skipToken } from "@tanstack/react-query";
import {
  Plus,
  Search,
  ArrowLeft,
  Activity,
  BookOpen,
  CalendarDays,
  MessageCircle,
  Sparkles,
  Pencil,
  UserRound,
  Link2,
  Target,
} from "lucide-react";
import { api } from "../data/api";
import { names } from "../domain/privacy";
import { useAuth } from "../auth/Auth";
import { usePatients, useWrite, useAction } from "./hooks";
import { Heading, Loading, ErrorBox, Empty, DirtyGuard, date } from "./shared";
import type { Patient, ToolType } from "../domain/types";
import { PatientTitle, useReadOnDisplay } from "./App";
export function PatientsPage() {
  const patients = usePatients(),
    { session } = useAuth();
  const [search, setSearch] = useState("");
  const write = useWrite();
  const label = (p: Patient) =>
    names.get(localStorage, session!.user.id, p.id) || he.Ai004;
  const filtered = patients.data?.filter(
    (p) => label(p).includes(search) || String(p.id).includes(search),
  );
  return (
    <>
      <Heading
        title={he.Patients001}
        description={he.Patients002}
        action={
          write && (
            <Link className="button" to="/patients/new">
              <Plus size={18} />
              {he.Patients003}
            </Link>
          )
        }
      />
      <div className="toolbar">
        <label className="search">
          <Search size={19} />
          <input
            aria-label={he.Patients004}
            placeholder={he.Patients005}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </label>
        <span>
          {patients.data?.length ?? 0} {he.App008}
        </span>
      </div>
      {patients.isPending ? (
        <Loading />
      ) : patients.isError ? (
        <ErrorBox
          error={patients.error}
          retry={() => void patients.refetch()}
        />
      ) : filtered?.length ? (
        <div className="patient-grid">
          {filtered.map((p) => (
            <Link to={`/patients/${p.id}`} className="patient-card" key={p.id}>
              <div className="patient-card-top">
                <span className="avatar">
                  <UserRound />
                </span>
                <span className={`status ${p.active ? "active" : ""}`}>
                  {p.active ? he.Patients006 : he.Patients007}
                </span>
              </div>
              <h2>{label(p)}</h2>
              <p className="muted small">
                {he.Patients008}
                <bdi>{String(p.id).slice(0, 8)}</bdi>
              </p>
              <p className="clamp">
                {String(p.formulation?.treatmentGoal || he.Patients009)}
              </p>
              <span className="card-link">
                {he.Patients010}
                <ArrowLeft size={18} />
              </span>
            </Link>
          ))}
        </div>
      ) : (
        <Empty>{search ? he.Patients011 : he.Patients012}</Empty>
      )}
    </>
  );
}
export function PatientPage() {
  const { patientId: id = "" } = useParams();
  const { session } = useAuth();
  const patient = useQuery({
    queryKey: [session!.user.id, "patient", id],
    queryFn: () => api.patient(id),
  });
  const sessions = useQuery({
    queryKey: [session!.user.id, "sessions", id],
    queryFn: () => api.sessions(id),
  });
  const connection = useQuery({
    queryKey: [session!.user.id, "connection", id],
    queryFn: () => api.connected(id),
    staleTime: 60_000,
  });
  const prep = useQuery<{
    preparation: Record<string, import("../domain/types").Clinical>;
    generatedAt: string;
  }>({ queryKey: [session!.user.id, "preparation", id], queryFn: skipToken, enabled: false });
  const write = useWrite();
  useReadOnDisplay(!!patient.data);
  if (patient.isPending) return <Loading />;
  if (patient.isError) return <ErrorBox error={patient.error} />;
  const p = patient.data;
  const name = names.get(localStorage, session!.user.id, id) || he.Ai004;
  return (
    <>
      <div className="breadcrumb">
        <Link to="/patients">{he.Patients001}</Link>
        <span>/</span>
        <span>{name}</span>
      </div>
      <Heading
        title={name}
        description={p.active ? he.Patients006 : he.Patients013}
        action={
          <Link className="secondary button" to={`/patients/${id}/edit`}>
            <Pencil size={16} />
            {he.Patients014}
          </Link>
        }
      />
      <section className="goal-panel">
        <Target size={26} />
        <div>
          <span className="eyebrow">{he.Patients015}</span>
          <p>{String(p.formulation?.treatmentGoal || he.Patients009)}</p>
        </div>
      </section>
      <div className="connection">
        <Link2 size={19} />
        <span>
          {connection.isPending
            ? he.Patients016
            : connection.isError
              ? he.Patients017
              : connection.data
                ? he.Patients018
                : he.Patients019}
        </span>
      </div>
      <div className="overview-grid">
        {[
          [CalendarDays, "sessions", he.App009, he.Patients020],
          [Activity, "questionnaires", he.Patients021, he.Patients022],
          [BookOpen, "diaries/1", he.Patients023, he.Patients024],
          [BookOpen, "diaries/2", he.Patients025, he.Patients026],
          [BookOpen, "diaries/3", he.Patients027, he.Patients028],
          [MessageCircle, "messages", he.Inbox013, he.Patients029],
        ].map(([Icon, path, title, description]) => {
          const Glyph = Icon as typeof CalendarDays;
          return (
            <Link
              className="overview-card"
              to={`/patients/${id}/${path}`}
              key={String(path)}
            >
              <Glyph size={23} />
              <div>
                <h2>{String(title)}</h2>
                <p>{String(description)}</p>
              </div>
              <ArrowLeft size={18} />
            </Link>
          );
        })}
      </div>
      <div className="two-col">
        <section className="panel">
          <div className="section-heading">
            <h2>{he.Patients030}</h2>
            {write && (
              <Link to={`/patients/${id}/sessions/new`}>{he.Patients031}</Link>
            )}
          </div>
          {sessions.isPending ? (
            <Loading />
          ) : sessions.isError ? (
            <ErrorBox error={sessions.error} />
          ) : sessions.data?.[0] ? (
            <Link
              className="session-preview"
              to={`/patients/${id}/sessions/${sessions.data[0].id}`}
            >
              <CalendarDays />
              <div>
                <strong>{date(sessions.data[0].session_date)}</strong>
                <p className="clamp">
                  {sessions.data[0].notes || he.Patients032}
                </p>
              </div>
            </Link>
          ) : (
            <p className="muted">{he.Patients033}</p>
          )}
        </section>
        <section className="panel ai-feature">
          <Sparkles />
          <h2>{he.Patients034}</h2>
          <p>
            {prep.data
              ? String(
                  prep.data.preparation.executive_summary ?? he.Patients035,
                )
              : he.Patients035}
          </p>
          {prep.data && <p className="small">{date(prep.data.generatedAt)}</p>}
          <div className="actions">
            <Link className="button secondary" to={`/patients/${id}/prepare`}>
              {he.Ai017}
            </Link>
            <Link to={`/patients/${id}/ai`}>{he.Ai001}</Link>
          </div>
        </section>
      </div>
      {p.notes && (
        <section className="panel">
          <h2>{he.Patients036}</h2>
          <p className="prose">{p.notes}</p>
        </section>
      )}
    </>
  );
}
export function PatientEdit() {
  const { patientId: id } = useParams();
  const { session } = useAuth();
  const p = useQuery({
    queryKey: [session!.user.id, "patient", id],
    queryFn: () => api.patient(id!),
    enabled: !!id,
  });
  if (id && p.isPending) return <Loading />;
  if (id && p.isError && !p.data) return <ErrorBox error={p.error} />;
  return <EditForm key={id ?? "new"} patient={p.data} />;
}
function EditForm({ patient: p }: { patient?: Patient }) {
  const { session } = useAuth(),
    navigate = useNavigate(),
    write = useWrite();
  const originalName = p ? names.get(localStorage, session!.user.id, p.id) : "";
  const [name, setName] = useState(originalName),
    [goal, setGoal] = useState(String(p?.formulation?.treatmentGoal ?? "")),
    [notes, setNotes] = useState(p?.notes ?? ""),
    [active, setActive] = useState(p?.active ?? true),
    [saved, setSaved] = useState(false);
  const dirty =
    !saved &&
    (name !== originalName ||
      goal !== String(p?.formulation?.treatmentGoal ?? "") ||
      notes !== (p?.notes ?? "") ||
      active !== (p?.active ?? true));
  const created = useRef<Patient | undefined>(undefined);
  const save = useAction(async () => {
    let target = p ?? created.current;
    if (!target) {
      target = await api.createPatient(active);
      created.current = target;
    }
    if (
      p &&
      write &&
      (goal !== String(p.formulation?.treatmentGoal ?? "") ||
        notes !== (p.notes ?? "") ||
        active !== p.active)
    )
      await api.updatePatient(p, goal, notes, active);
    names.set(localStorage, session!.user.id, target.id, name);
    setSaved(true);
    return target.id;
  });
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (save.isPending) return;
    try {
      const id = await save.mutateAsync();
      setTimeout(() => navigate(`/patients/${id}`), 0);
    } catch {
      /* inline error */
    }
  }
  return (
    <>
      <Heading title={p ? he.Patients037 : he.Patients038} />
      <DirtyGuard dirty={dirty} />
      <form className="panel form-panel" onSubmit={submit}>
        <label>
          {he.Patients039}
          <input
            value={name}
            maxLength={150}
            onChange={(e) => setName(e.target.value)}
          />
        </label>
        <p className="notice">{he.Patients040}</p>
        {p && (
          <fieldset disabled={!write}>
            <label>
              {he.Patients015}
              <textarea
                rows={3}
                value={goal}
                onChange={(e) => setGoal(e.target.value)}
              />
            </label>
            <label>
              {he.Patients036}
              <textarea
                rows={5}
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
              />
            </label>
            <label className="check">
              <input
                type="checkbox"
                checked={active}
                onChange={(e) => setActive(e.target.checked)}
              />
              {he.Patients006}
            </label>
          </fieldset>
        )}
        {save.isError && <ErrorBox error={save.error} />}
        <div className="actions">
          <button disabled={save.isPending || (!p && !write)} type="submit">
            {save.isPending ? he.Patients041 : he.Patients042}
          </button>
          <Link to={p ? `/patients/${p.id}` : "/patients"}>
            {he.Patients043}
          </Link>
        </div>
      </form>
    </>
  );
}
export function AssignmentControl({
  id,
  type,
}: {
  id: string;
  type: ToolType;
}) {
  const { session } = useAuth();
  const write = useWrite();
  const assignments = useQuery({
    queryKey: [session!.user.id, "assignments", id],
    queryFn: () => api.assignments(id),
  });
  const connected = useQuery({
    queryKey: [session!.user.id, "connection", id],
    queryFn: () => api.connected(id),
    staleTime: 60_000,
  });
  const active = assignments.data?.find(
    (a) => a.type === type && a.cancelled_at === null && a.session_id === null,
  );
  const action = useAction(async () =>
    active ? api.deactivate(active.id) : api.activate(id, type),
  );
  return (
    <div className="assignment-strip">
      <div>
        <strong>
          {assignments.isPending
            ? he.Patients044
            : assignments.isError
              ? he.Patients045
              : active
                ? he.Patients046
                : he.Patients047}
        </strong>
        <p>
          {active
            ? he.Patients048
            : connected.data
              ? he.Patients049
              : he.Patients050}
        </p>
      </div>
      {type !== "diary_3" && (
        <button
          className="secondary"
          disabled={
            !write ||
            !connected.data ||
            assignments.isPending ||
            assignments.isError ||
            action.isPending
          }
          onClick={() => action.mutate()}
        >
          {action.isPending
            ? he.Patients051
            : active
              ? he.Patients052
              : he.Patients053}
        </button>
      )}
      {action.isError && <ErrorBox error={action.error} />}
    </div>
  );
}
export function PatientBreadcrumb({
  id,
  title,
}: {
  id: string;
  title: string;
}) {
  return (
    <div className="breadcrumb">
      <PatientTitle id={id} />
      <span>/</span>
      <span>{title}</span>
    </div>
  );
}
