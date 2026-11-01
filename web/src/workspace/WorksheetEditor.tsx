import mobile from "../mobile-he.json";
import { DiaryWorksheet } from "./DiaryWorksheet";
import { todayLocal, updateItem, type Worksheet } from "./model";
import { questionnaireScore } from "./scores";
import { ww } from "./he";
export function WorksheetEditor({ item, onChange, disabled, shared = false }: { item: Worksheet; onChange: (next: Worksheet) => void; disabled: boolean; shared?: boolean }) {
  const d = item.data;
  const set = (key: string, value: unknown) => onChange(updateItem(item, { data: { [key]: value } }));
  if (item.type === "questionnaire") {
    const gad = Array.from({ length: 7 }, (_, i) => Array.isArray(d.gad7_answers) ? d.gad7_answers[i] ?? null : null) as (number | null)[];
    const phq = Array.from({ length: 9 }, (_, i) => Array.isArray(d.phq9_answers) ? d.phq9_answers[i] ?? null : null) as (number | null)[];
    return <div className="ww-sheet-stack"><section className="ww-sheet"><label htmlFor="measurement-date">{ww.date}</label><input id="measurement-date" type="date" value={item.measurement_date ?? ""} max={todayLocal()} disabled={disabled} onChange={(e) => onChange(updateItem(item, { measurement_date: e.target.value }))} /><div className="ww-scores" role="status" aria-live="polite"><ScoreSummary values={gad} kind="gad" /><ScoreSummary values={phq} kind="phq" /></div></section>
      {([mobile.gad7_questions, mobile.phq9_questions] as string[][]).map((questions, group) => <section className="ww-sheet" key={group}><h2>{group === 0 ? mobile.gad7_title : mobile.phq9_title}</h2><p>{group === 0 ? mobile.gad7_main_question : mobile.phq9_main_question}</p>{questions.map((question, index) => { const values = group === 0 ? gad : phq; return <fieldset className="ww-question" key={index} disabled={disabled}><legend>{index + 1}. {question}</legend><div className="ww-options">{mobile.answer_descriptions.map((label, value) => <label key={value} className={values[index] === value ? "selected" : ""}><input type="radio" name={`${item.id}-${group}-${index}`} checked={values[index] === value} onChange={() => set(group === 0 ? "gad7_answers" : "phq9_answers", values.map((answer, i) => i === index ? value : answer))} /><b>{value}</b><span>{label}</span></label>)}</div>{group === 1 && index === 8 && values[index] !== null && Number(values[index]) > 0 && <p className="ww-safety" role="alert">{ww.safety}</p>}</fieldset>; })}</section>)}
      <section className="ww-sheet"><fieldset disabled={disabled}><legend>{mobile.phq9_interference_question.replaceAll("**", "")}</legend><div className="ww-options ww-options-compact">{mobile.phq9_interference_options.map((label, value) => <label key={value} className={d.interference_level === value ? "selected" : ""}><input type="radio" name={`${item.id}-interference`} checked={d.interference_level === value} onChange={() => set("interference_level", value)} />{label}</label>)}</div></fieldset>{!shared && <><label htmlFor={`${item.id}-note`}>{ww.optionalNote}</label><textarea id={`${item.id}-note`} rows={3} maxLength={50000} disabled={disabled} value={String(d.notes ?? "")} onChange={(e) => set("notes", e.target.value)} /></>}</section>
    </div>;
  }
  return <DiaryWorksheet item={item} onChange={onChange} disabled={disabled} />;
}

function ScoreSummary({ values, kind }: { values: (number | null)[]; kind: "gad" | "phq" }) {
  const result = questionnaireScore(values, kind);
  return <div className={`ww-score ww-tone-${result.tone}`}><b dir="ltr">{kind === "gad" ? "GAD-7" : "PHQ-9"}</b>{result.total === null ? <span>{result.answered} מתוך {result.count} תשובות · השאלון טרם הושלם</span> : <><span>ציון כולל: <strong>{result.total}</strong> / {kind === "gad" ? 21 : 27}</span><span>{result.label}</span></>}</div>;
}
