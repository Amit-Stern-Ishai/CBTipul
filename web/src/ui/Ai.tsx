import { he } from "../he";
import { useState, type FormEvent } from "react";
import { Link, useParams } from "react-router-dom";
import { useQueryClient } from "@tanstack/react-query";
import { Sparkles, Send, UserRound, ArrowLeft } from "lucide-react";
import { api } from "../data/api";
import { useAuth } from "../auth/Auth";
import { names } from "../domain/privacy";
import type { Clinical, Turn } from "../domain/types";
import { useAction, usePatients, useWrite } from "./hooks";
import {
  Heading,
  Loading,
  ErrorBox,
  Empty,
  ClinicalContent,
  date,
} from "./shared";
import { PatientBreadcrumb } from "./Patients";
import mobile from "../mobile-he.json";
export function AiPage() {
  const { patientId: id } = useParams();
  return id ? <Chat key={id} id={id} /> : <AiPicker />;
}
function AiPicker() {
  const patients = usePatients(),
    { session } = useAuth();
  return (
    <>
      <Heading title={he.Ai001} description={he.Ai002} />
      {patients.isPending ? (
        <Loading />
      ) : patients.isError ? (
        <ErrorBox error={patients.error} />
      ) : !patients.data.length ? (
        <Empty>{he.Ai003}</Empty>
      ) : (
        <div className="patient-grid">
          {patients.data.map((p) => (
            <Link
              className="patient-card"
              to={`/patients/${p.id}/ai`}
              key={p.id}
            >
              <UserRound />
              <h2>
                {names.get(localStorage, session!.user.id, p.id) || he.Ai004}
              </h2>
              <span className="ai-chip">
                <Sparkles size={15} />
                {he.Ai005}
                <ArrowLeft size={15} />
              </span>
            </Link>
          ))}
        </div>
      )}
    </>
  );
}
function Chat({ id }: { id: string }) {
  const { session } = useAuth(),
    write = useWrite();
  const [turns, setTurns] = useState<Turn[]>([]),
    [draft, setDraft] = useState(""),
    [unavailable, setUnavailable] = useState<string[]>([]);
  const chat = useAction((next: Turn[]) => api.chat(id, next));
  const name = names.get(localStorage, session!.user.id, id) || he.Ai006;
  async function send(e: FormEvent) {
    e.preventDefault();
    if (!draft.trim() || chat.isPending) return;
    const next: Turn[] = [...turns, { role: "user", content: draft.trim() }];
    try {
      const answer = await chat.mutateAsync(next);
      setTurns([...next, { role: "assistant", content: answer.content }]);
      setUnavailable(answer.unavailable);
      setDraft("");
    } catch {
      /* keep text for retry */
    }
  }
  return (
    <>
      <PatientBreadcrumb id={id} title={he.Ai001} />
      <Heading title={he.Ai007(name)} />
      <div className="chat">
        <div className="chat-body" aria-live="polite">
          {!turns.length ? (
            <div className="chat-empty">
              <span className="ai-orb">
                <Sparkles size={34} />
              </span>
              <h2>{he.Ai008}</h2>
              <p>{he.Ai009}</p>
              <div className="suggestions">
                {mobile.ai_suggested_questions.map((s) => (
                  <button
                    className="secondary"
                    key={s}
                    onClick={() => setDraft(s)}
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>
          ) : (
            turns.map((t, i) => (
              <article className={`bubble ${t.role}`} key={i}>
                <strong>{t.role === "user" ? he.Ai010 : he.Ai011}</strong>
                <p className="prose">{t.content}</p>
              </article>
            ))
          )}
          {chat.isPending && <Loading />}
        </div>
        {unavailable.length > 0 && <p className="notice">{he.Ai012}</p>}
        {chat.isError && <ErrorBox error={chat.error} />}
        <form onSubmit={send} className="chat-compose">
          <textarea
            aria-label={he.Ai013}
            placeholder={he.Ai014}
            rows={2}
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            disabled={!write}
          />
          <button
            disabled={!write || chat.isPending || !draft.trim()}
            aria-label={he.Ai015}
          >
            <Send size={20} />
          </button>
        </form>
      </div>
      <p className="small disclaimer">{he.Ai016}</p>
    </>
  );
}
const preparationOrder = [
  "executive_summary",
  "assignments_to_check",
  "priority_follow_ups",
  "recurring_nats",
  "cbt_cycles",
  "questionnaire_insights",
  "treatment_focus",
  "suggested_questions",
  "core_belief_hypothesis",
];
export function PreparationPage() {
  const { patientId: id = "" } = useParams(),
    { session } = useAuth(),
    write = useWrite(),
    client = useQueryClient();
  const key = [session!.user.id, "preparation", id];
  const [result, setResult] = useState(
    client.getQueryData<{
      preparation: Record<string, Clinical>;
      unavailable: string[];
      generatedAt: string;
    }>(key),
  );
  const action = useAction(() => api.prepare(id));
  return (
    <>
      <PatientBreadcrumb id={id} title={he.Ai017} />
      <Heading
        title={he.Ai018}
        description={he.Ai019}
        action={
          <button
            disabled={!write || action.isPending}
            onClick={async () => {
              try {
                const r = await action.mutateAsync();
                client.setQueryData(key, r);
                setResult(r);
              } catch {
                /* inline */
              }
            }}
          >
            <Sparkles size={18} />
            {action.isPending ? he.Ai020 : result ? he.Ai021 : he.Ai022}
          </button>
        }
      />
      <p className="notice">{he.Ai023}</p>
      {action.isError && <ErrorBox error={action.error} />}{" "}
      {action.isPending && <Loading />}
      {result ? (
        <>
          <p className="small">
            {he.Ai024}
            {date(result.generatedAt)} {he.Ai025}
          </p>
          {result.unavailable.length > 0 && (
            <p className="notice">{he.Ai026}</p>
          )}
          {preparationOrder
            .filter((k) => result.preparation[k])
            .map((k) => (
              <section className="panel" key={k}>
                <ClinicalContent value={{ [k]: result.preparation[k] }} />
              </section>
            ))}
        </>
      ) : (
        !action.isPending && <Empty>{he.Ai027}</Empty>
      )}
    </>
  );
}
