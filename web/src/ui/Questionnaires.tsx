import { he } from "../he";
import { useState, type FormEvent } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Activity, Plus } from "lucide-react";
import { api } from "../data/api";
import { useAuth } from "../auth/Auth";
import { useAction, useWrite } from "./hooks";
import {
  Heading,
  Loading,
  ErrorBox,
  Empty,
  DirtyGuard,
  date,
  today,
} from "./shared";
import { AssignmentControl, PatientBreadcrumb } from "./Patients";
import {
  chronological,
  score,
  trend,
  trendLabels,
} from "../domain/questionnaires";
import type { Questionnaire } from "../domain/types";
import mobile from "../mobile-he.json";
import { useReadOnDisplay } from "./App";
export function useQuestionnaires(id: string) {
  const { session } = useAuth();
  return useQuery({
    queryKey: [session!.user.id, "questionnaires", id],
    queryFn: () => api.questionnaires(id),
  });
}
export function Scores({ q }: { q: Questionnaire }) {
  return (
    <div className="scores">
      <span>
        <bdi>GAD-7</bdi>
        <b>{score(q.gad7_answers, 7) ?? "—"}</b>
        <small>/21</small>
      </span>
      <span>
        <bdi>PHQ-9</bdi>
        <b>{score(q.phq9_answers, 9) ?? "—"}</b>
        <small>/27</small>
      </span>
    </div>
  );
}
export function QuestionnairesPage() {
  const { patientId: id = "" } = useParams(),
    write = useWrite();
  const rows = useQuestionnaires(id);
  const [tab, setTab] = useState("history");
  return (
    <>
      <PatientBreadcrumb id={id} title={he.Patients021} />
      <Heading
        title={he.Patients021}
        description={he.Questionnaires001}
        action={
          write && (
            <Link className="button" to={`/patients/${id}/questionnaires/new`}>
              <Plus size={18} />
              {he.Questionnaires002}
            </Link>
          )
        }
      />
      <AssignmentControl id={id} type="questionnaire" />
      <div className="tabs" role="tablist" aria-label={he.Questionnaires003}>
        <button
          role="tab"
          aria-selected={tab === "history"}
          className={tab === "history" ? "selected" : ""}
          onClick={() => setTab("history")}
        >
          {he.Questionnaires004}
        </button>
        <button
          role="tab"
          aria-selected={tab === "trends"}
          className={tab === "trends" ? "selected" : ""}
          onClick={() => setTab("trends")}
        >
          {he.Questionnaires005}
        </button>
      </div>
      {rows.isPending ? (
        <Loading />
      ) : rows.isError ? (
        <ErrorBox error={rows.error} retry={() => void rows.refetch()} />
      ) : !rows.data.length ? (
        <Empty>{he.Questionnaires006}</Empty>
      ) : tab === "trends" ? (
        <Trends rows={rows.data} />
      ) : (
        <div className="list panel">
          {rows.data.map((q) => (
            <Link
              className="list-row"
              to={`/patients/${id}/questionnaires/${q.id}`}
              key={q.id}
            >
              <span className="icon-tile">
                <Activity />
              </span>
              <div>
                <strong>{he.Questionnaires007}</strong>
                <p>
                  {date(q.answered_date)} ·{" "}
                  {q.created_by === "patient"
                    ? he.Questionnaires008
                    : he.Questionnaires009}
                </p>
              </div>
              <Scores q={q} />
            </Link>
          ))}
        </div>
      )}
    </>
  );
}
function Chart({
  values,
  max,
  title,
}: {
  values: { day: string; value: number | null }[];
  max: number;
  title: string;
}) {
  const points = values.map((v, i) => ({
    ...v,
    x: 36 + i * (524 / Math.max(values.length - 1, 1)),
    y: v.value === null ? null : 160 - (v.value / max) * 130,
  }));
  return (
    <figure className="chart">
      <figcaption>{title}</figcaption>
      <svg viewBox="0 0 600 215" role="img" aria-label={title} direction="ltr">
        {[0, max / 2, max].map((n) => (
          <g key={n}>
            <line
              x1="36"
              x2="560"
              y1={160 - (n / max) * 130}
              y2={160 - (n / max) * 130}
              stroke="#dbe6e5"
            />
            <text
              x="20"
              y={164 - (n / max) * 130}
              fontSize="12"
              fill="#556775"
              textAnchor="middle"
            >
              {n}
            </text>
          </g>
        ))}
        {points
          .slice(1)
          .map((p, i) =>
            p.y !== null && points[i].y !== null ? (
              <line
                key={i}
                x1={points[i].x}
                y1={points[i].y!}
                x2={p.x}
                y2={p.y}
                stroke="#236d75"
                strokeWidth="3"
              />
            ) : null,
          )}
        {points.map((p, i) => (
          <g key={i}>
            {p.y !== null && (
              <circle cx={p.x} cy={p.y} r="5" fill="#236d75">
                <title>
                  {date(p.day)}: {p.value}
                </title>
              </circle>
            )}
            {(i === 0 || i === points.length - 1) && (
              <text
                x={p.x}
                y="198"
                fontSize="11"
                textAnchor={i === 0 ? "start" : "end"}
                fill="#556775"
              >
                {date(p.day)}
              </text>
            )}
          </g>
        ))}
      </svg>
      <details>
        <summary>{he.Questionnaires010}</summary>
        <table>
          <thead>
            <tr>
              <th>{he.Questionnaires011}</th>
              <th>{he.Questionnaires012}</th>
            </tr>
          </thead>
          <tbody>
            {values.map((v, i) => (
              <tr key={i}>
                <td>{date(v.day)}</td>
                <td>{v.value ?? he.Questionnaires013}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </details>
    </figure>
  );
}
function Trends({ rows }: { rows: Questionnaire[] }) {
  const sorted = chronological(rows);
  const allQuestions = [...mobile.gad7_questions, ...mobile.phq9_questions];
  const [filter, setFilter] = useState(0),
    [question, setQuestion] = useState<number | null>(null);
  const values = allQuestions.map((_, i) =>
    sorted.map((q) =>
      i < 7 ? (q.gad7_answers[i] ?? null) : (q.phq9_answers[i - 7] ?? null),
    ),
  );
  const candidates = allQuestions.map((text, i) => ({
    text,
    i,
    trend: trend(values[i]),
  }));
  const matching = candidates.filter((c) => c.trend === filter);
  const selection = matching.find((c) => c.i === question) ?? matching[0];
  return (
    <>
      <div className="two-col">
        <Chart
          title={he.Questionnaires014}
          max={21}
          values={sorted.map((q) => ({
            day: q.answered_date!,
            value: score(q.gad7_answers, 7),
          }))}
        />
        <Chart
          title={he.Questionnaires015}
          max={27}
          values={sorted.map((q) => ({
            day: q.answered_date!,
            value: score(q.phq9_answers, 9),
          }))}
        />
      </div>
      <section className="panel">
        <h2>{he.Questionnaires016}</h2>
        <p>{he.Questionnaires017}</p>
        <div className="form-row">
          <label>
            {he.Questionnaires018}
            <select
              aria-label={he.Questionnaires018}
              value={filter}
              onChange={(e) => {
                setFilter(Number(e.target.value));
                setQuestion(null);
              }}
            >
              {trendLabels.map((l, i) => (
                <option key={i} value={i}>
                  {l} — {candidates.filter((c) => c.trend === i).length}{" "}
                  {he.Questionnaires019}
                </option>
              ))}
            </select>
          </label>
          <label>
            {he.Questionnaires020}
            <select
              aria-label={he.Questionnaires020}
              disabled={!matching.length}
              value={selection?.i ?? ""}
              onChange={(e) => setQuestion(Number(e.target.value))}
            >
              {!matching.length && (
                <option value="">{he.Questionnaires021}</option>
              )}
              {matching.map((c) => (
                <option key={c.i} value={c.i}>
                  {c.text}
                </option>
              ))}
            </select>
          </label>
        </div>
        {selection && (
          <Chart
            title={selection.text}
            max={3}
            values={sorted.map((q, i) => ({
              day: q.answered_date!,
              value: values[selection.i][i],
            }))}
          />
        )}
      </section>
    </>
  );
}
export function QuestionnaireForm() {
  const { patientId: id = "" } = useParams();
  const rows = useQuestionnaires(id);
  return <QuestionnaireEditor key={id} id={id} history={rows.data ?? []} />;
}
function QuestionnaireEditor({
  id,
  history,
}: {
  id: string;
  history: Questionnaire[];
}) {
  const navigate = useNavigate(),
    write = useWrite();
  const [answers, setAnswers] = useState<(number | null)[]>(
      Array(16).fill(null),
    ),
    [notes, setNotes] = useState<string[]>(Array(16).fill("")),
    [day, setDay] = useState(today()),
    [interference, setInterference] = useState<number | null>(null),
    [interferenceNote, setInterferenceNote] = useState(""),
    [saved, setSaved] = useState(false);
  const previous = history.find(
    (q) => q.answered_date && q.answered_date <= day,
  );
  const save = useAction(() =>
    api.saveQuestionnaire({
      patient_id: id,
      session_id: null,
      answered_date: day,
      created_by: "therapist",
      gad7_answers: answers.slice(0, 7) as number[],
      phq9_answers: answers.slice(7) as number[],
      interference_level: interference,
      combined_notes: {
        gad7: notes.slice(0, 7),
        phq9: notes.slice(7),
        interference: interferenceNote,
      },
    }),
  );
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (save.isPending) return;
    try {
      const result = await save.mutateAsync();
      setSaved(true);
      setTimeout(
        () => navigate(`/patients/${id}/questionnaires/${result.id}`),
        0,
      );
    } catch {
      /* inline */
    }
  }
  return (
    <>
      <PatientBreadcrumb id={id} title={he.Questionnaires022} />
      <Heading title={he.Questionnaires022} />
      <DirtyGuard
        dirty={
          !saved &&
          (answers.some((a) => a !== null) ||
            notes.some(Boolean) ||
            interference !== null ||
            !!interferenceNote)
        }
      />
      <form onSubmit={submit}>
        <fieldset disabled={!write || save.isPending}>
          <section className="panel">
            <label>
              {he.Questionnaires023}
              <input
                type="date"
                required
                max={today()}
                value={day}
                onChange={(e) => setDay(e.target.value)}
              />
            </label>
            <p className="small">{he.Questionnaires024}</p>
            <div className="answer-key">
              {mobile.answer_descriptions.map((label, i) => (
                <span key={i}>
                  <b>{i}</b>
                  {label}
                </span>
              ))}
            </div>
            {previous && (
              <p className="notice compact">
                {he.Questionnaires025}
                {date(previous.answered_date)} {he.Questionnaires026}
              </p>
            )}
          </section>
          {[mobile.gad7_questions, mobile.phq9_questions].map(
            (questions, group) => (
              <section className="panel" key={group}>
                <h2>{group === 0 ? mobile.gad7_title : mobile.phq9_title}</h2>
                <p className="main-question">
                  {group === 0
                    ? mobile.gad7_main_question
                    : mobile.phq9_main_question}
                </p>
                {questions.map((text, j) => {
                  const i = j + (group ? 7 : 0);
                  const prev = group
                    ? previous?.phq9_answers[j]
                    : previous?.gad7_answers[j];
                  return (
                    <fieldset className="question" key={i}>
                      <legend>
                        {j + 1}. {text}
                      </legend>
                      <div className="answer-options">
                        {mobile.answer_descriptions.map((label, value) => (
                          <label
                            className={answers[i] === value ? "chosen" : ""}
                            key={value}
                          >
                            <input
                              type="radio"
                              name={`q-${i}`}
                              value={value}
                              required
                              checked={answers[i] === value}
                              onChange={() =>
                                setAnswers((a) =>
                                  a.map((v, n) => (n === i ? value : v)),
                                )
                              }
                            />
                            <b>{value}</b>
                            <span>{label}</span>
                          </label>
                        ))}
                      </div>
                      {prev !== undefined && (
                        <p className="small">
                          {he.Questionnaires027}
                          {prev} — {mobile.answer_descriptions[prev]}
                        </p>
                      )}
                      <details>
                        <summary>{he.Questionnaires028}</summary>
                        <textarea
                          aria-label={he.Questionnaires029(text)}
                          value={notes[i]}
                          onChange={(e) =>
                            setNotes((a) =>
                              a.map((v, n) => (n === i ? e.target.value : v)),
                            )
                          }
                        />
                      </details>
                      {i === 15 && answers[i] !== null && answers[i]! > 0 && (
                        <Safety />
                      )}
                    </fieldset>
                  );
                })}
              </section>
            ),
          )}
          <section className="panel">
            <fieldset>
              <legend>
                {mobile.phq9_interference_question.replaceAll("**", "")}
              </legend>
              <div className="interference">
                {mobile.phq9_interference_options.map((label, i) => (
                  <label className="check" key={i}>
                    <input
                      required
                      type="radio"
                      name="interference"
                      checked={interference === i}
                      onChange={() => setInterference(i)}
                    />
                    {label}
                  </label>
                ))}
              </div>
              <label>
                {he.Questionnaires030}
                <textarea
                  rows={2}
                  value={interferenceNote}
                  onChange={(e) => setInterferenceNote(e.target.value)}
                />
              </label>
            </fieldset>
          </section>
        </fieldset>
        {save.isError && <ErrorBox error={save.error} />}
        <div className="sticky-actions">
          <span>
            {answers.filter((a) => a !== null).length} {he.Questionnaires031}
          </span>
          <button
            disabled={
              !write ||
              save.isPending ||
              answers.some((a) => a === null) ||
              interference === null
            }
          >
            {save.isPending ? he.Patients041 : he.Questionnaires032}
          </button>
        </div>
      </form>
    </>
  );
}
function Safety() {
  return <div className="error">{he.Questionnaires033}</div>;
}
export function QuestionnaireDetail() {
  const { patientId: id = "", questionnaireId: qid = "" } = useParams();
  const rows = useQuestionnaires(id);
  const q = rows.data?.find((q) => String(q.id) === qid);
  useReadOnDisplay(!!q);
  return (
    <>
      <PatientBreadcrumb id={id} title={he.Questionnaires007} />
      {rows.isPending ? (
        <Loading />
      ) : rows.isError ? (
        <ErrorBox error={rows.error} />
      ) : !q ? (
        <Empty>{he.Questionnaires034}</Empty>
      ) : (
        <>
          <Heading
            title={he.Questionnaires007}
            description={he.Questionnaires035(date(q.answered_date))}
          />
          <div className="panel result-header">
            <p>
              {q.created_by === "patient"
                ? he.Questionnaires036
                : he.Questionnaires009}
            </p>
            <Scores q={q} />
          </div>
          {q.phq9_answers[8] > 0 && <Safety />}
          {[mobile.gad7_questions, mobile.phq9_questions].map(
            (questions, g) => (
              <section className="panel" key={g}>
                <h2>{g ? mobile.phq9_title : mobile.gad7_title}</h2>
                {questions.map((text, i) => {
                  const answer = (g ? q.phq9_answers : q.gad7_answers)[i];
                  return (
                    <div className="result-question" key={i}>
                      <div>
                        <strong>
                          {i + 1}. {text}
                        </strong>
                        {(g
                          ? q.combined_notes?.phq9
                          : q.combined_notes?.gad7)?.[i] && (
                          <p className="prose">
                            {
                              (g
                                ? q.combined_notes?.phq9
                                : q.combined_notes?.gad7)?.[i]
                            }
                          </p>
                        )}
                      </div>
                      <span>
                        {answer !== undefined
                          ? `${answer} · ${mobile.answer_descriptions[answer]}`
                          : he.Questionnaires037}
                      </span>
                    </div>
                  );
                })}
              </section>
            ),
          )}
          <section className="panel">
            <h2>{he.Questionnaires038}</h2>
            <p>
              {q.interference_level === null
                ? he.Questionnaires037
                : mobile.phq9_interference_options[q.interference_level]}
            </p>
            <p className="prose">{q.combined_notes?.interference}</p>
          </section>
        </>
      )}
    </>
  );
}
