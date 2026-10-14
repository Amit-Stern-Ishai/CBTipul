import { appAsset } from "../domain/urls";
import { useEffect, useRef, useState } from "react";
import { Check, CircleHelp, Clock3, FilePlus2, LogOut, Plus, RotateCw, Trash2 } from "lucide-react";
import { he } from "../he";
import mobile from "../mobile-he.json";
import { unsaved } from "../domain/dirty";
import { grantWorkspaceClinicalConsent } from "../data/api";
import { WorkspaceEngine, type WorkspaceViewState } from "./engine";
import { createWorksheet, finishProblems, isFormComplete, questionnaireFlags, thinkingErrors, todayLocal, updateItem, type Worksheet, type WorksheetType, type WorkspacePayload } from "./model";
import { questionnaireScore } from "./scores";
import { ww } from "./he";

type WorksheetFeedback = { status: "idle" | "busy" | "saved" | "failed"; submitted: string };
const titles: Record<WorksheetType, string> = { questionnaire: ww.question, diary_one: ww.diaryOne, diary_two: ww.diaryTwo, diary_three: ww.diaryThree };
const dateTime = (value: string) => new Intl.DateTimeFormat("he-IL", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
const message = (code: string | null) => code ? (ww.errors as Record<string, string>)[code] ?? ww.errors.network : null;

export function Workspace({ account, canWrite, logout }: { account: string; canWrite: boolean; logout: () => Promise<void> }) {
  const [view, setView] = useState<WorkspaceViewState>({ phase: "loading", save: "saved", envelope: null, payload: null, error: null, reminderAt: null, reminderOpen: false });
  const engineRef = useRef<WorkspaceEngine | null>(null);
  if (!engineRef.current) engineRef.current = new WorkspaceEngine(account, undefined, sessionStorage, setView);
  const engine = engineRef.current;
  const loaded = useRef(false);
  const mounted = useRef(false);
  const [selected, setSelected] = useState<string>("notes");
  const [worksheetFeedback, setWorksheetFeedback] = useState<Record<string, WorksheetFeedback>>({});
  const [showAdd, setShowAdd] = useState(false);
  const [finishOpen, setFinishOpen] = useState(false);
  const [discardOpen, setDiscardOpen] = useState(false);
  const [reference, setReference] = useState("");
  const [showProblems, setShowProblems] = useState(false);
  const finishRef = useRef<HTMLElement>(null);
  const discardRef = useRef<HTMLElement>(null);
  useEffect(() => { if (finishOpen) { finishRef.current?.focus(); finishRef.current?.scrollIntoView({ block: "center", behavior: "smooth" }); } }, [finishOpen]);
  useEffect(() => { if (discardOpen) { discardRef.current?.focus(); discardRef.current?.scrollIntoView({ block: "center", behavior: "smooth" }); } }, [discardOpen]);

  useEffect(() => {
    mounted.current = true;
    if (!loaded.current) { loaded.current = true; void engine.inspect(); }
    const interval = window.setInterval(() => { void engine.renew(); engine.checkReminder(); }, 30_000);
    const visible = () => { if (document.visibilityState === "visible") engine.checkReminder(); };
    document.addEventListener("visibilitychange", visible);
    return () => {
      mounted.current = false;
      window.clearInterval(interval);
      document.removeEventListener("visibilitychange", visible);
      queueMicrotask(() => { if (!mounted.current) engine.dispose(); });
    };
  }, [engine]);
  useEffect(() => {
    unsaved.active = view.save !== "saved" || view.phase === "finish_error";
    const beforeUnload = (event: BeforeUnloadEvent) => {
      if (!unsaved.active) return;
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", beforeUnload);
    return () => { window.removeEventListener("beforeunload", beforeUnload); unsaved.active = false; };
  }, [view.save, view.phase]);

  const payload = view.payload;
  const item = payload?.items.find((x) => x.id === selected);
  const problems = payload ? finishProblems(payload) : [];
  const edit = (next: WorkspacePayload) => engine.update(next);
  const editItem = (next: Worksheet) => {
    if (!payload) return;
    edit({ ...payload, items: payload.items.map((x) => x.id === next.id ? next : x) });
  };
  const add = (type: WorksheetType) => {
    if (!payload || payload.items.length >= 100 || type === "questionnaire" && payload.items.some((x) => x.type === "questionnaire")) return;
    const next = createWorksheet(type);
    edit({ ...payload, items: [...payload.items, next] });
    setSelected(next.id);
    setShowAdd(false);
  };
  const remove = (id: string) => {
    if (!payload || !window.confirm(ww.removeConfirm)) return;
    edit({ ...payload, items: payload.items.filter((x) => x.id !== id) });
    setSelected("notes");
  };
  const startFinish = () => {
    setShowProblems(true);
    if (problems.length) { const first = problems.find((x) => x !== "empty" && x !== "limit"); if (first) setSelected(first); return; }
    setFinishOpen(true);
  };
  const doFinish = async () => { try { await engine.finish(reference); setFinishOpen(false); } catch { /* Safe error state comes from engine. */ } };
  const doDiscard = async () => { try { await engine.discard(); setDiscardOpen(false); setSelected("notes"); } catch { /* Inline error. */ } };

  return <div className="ww-app" dir="rtl">
    <header className="ww-header">
      <div className="ww-brand"><img src={appAsset("brand.png")} alt="" /><span>CBTipul <small>{ww.title}</small></span></div>
      <div className="ww-header-actions">
        {view.phase === "editing" && <span className={`ww-save ww-save-${view.save}`} role="status" aria-live="polite">{view.save === "saved" ? <Check size={17} /> : <RotateCw size={17} />}{view.save === "saved" ? ww.statusSaved : view.save === "saving" ? ww.statusSaving : view.save === "offline" ? ww.statusOffline : ww.statusUnsaved}</span>}
        <a href="/" target="_blank" rel="noreferrer">{ww.publicSite}</a>
        <button type="button" className="ww-text-button" onClick={() => void logout()}><LogOut size={16} />{ww.signOut}</button>
      </div>
    </header>

    {view.phase !== "editing" && view.phase !== "lost" && view.phase !== "conflict" && <main className="ww-gate">
      {view.phase === "loading" && <div className="ww-neutral"><Clock3 size={28} /><h1>{ww.loading}</h1></div>}
      {view.phase === "start" && <div className="ww-neutral"><span className="ww-emblem"><FilePlus2 size={32} /></span><h1>{ww.title}</h1><p>{ww.startDescription}</p>{canWrite ? <button onClick={() => void engine.begin()}>{ww.start}</button> : <p className="ww-alert">{ww.readOnly}</p>}</div>}
      {view.phase === "resume" && <div className="ww-neutral"><span className="ww-emblem"><Clock3 size={32} /></span><h1>{ww.resumeTitle}</h1><p>{ww.resumeDescription}</p>{canWrite ? <button onClick={() => void engine.begin()}>{ww.resume}</button> : <p className="ww-alert">{ww.readOnly}</p>}</div>}
      {view.phase === "locked" && <div className="ww-neutral"><span className="ww-emblem"><CircleHelp size={32} /></span><h1>{ww.lockedTitle}</h1><p>{ww.lockedDescription}</p>{canWrite && <button onClick={() => void engine.begin(true)}>{ww.takeOver}</button>}{view.payload && <RecoveryCopy payload={view.payload} />}</div>}
      {view.phase === "error" && <div className="ww-neutral"><h1>{ww.title}</h1><p className="ww-alert" role="alert">{message(view.error)}</p><button onClick={() => void engine.inspect()}>{ww.retry}</button></div>}
      {view.phase === "finish_error" && <div className="ww-neutral"><h1>{ww.finishErrorTitle}</h1><p>{ww.finishErrorDescription}</p>{view.error && <p className="ww-alert" role="alert">{message(view.error)}</p>}<div className="ww-actions"><button onClick={() => void engine.retryFinish().catch(() => {})}>{ww.retry}</button>{["lease_lost", "revision_conflict"].includes(view.error ?? "") && <button className="secondary" onClick={() => void engine.recoverFailedFinish()}>{ww.returnToDraft}</button>}</div>{view.payload && <RecoveryCopy payload={view.payload} />}</div>}
      {view.phase === "finish_unconfirmed" && <div className="ww-neutral"><h1>{ww.finishErrorTitle}</h1><p>{ww.finishUnconfirmed}</p>{view.error && <p className="ww-alert" role="alert">{message(view.error)}</p>}<div className="ww-actions"><button onClick={() => void engine.inspect()}>{ww.retry}</button>{view.envelope && <button className="secondary" onClick={() => void engine.begin()}>{ww.returnToDraft}</button>}</div></div>}
      {view.phase === "success" && <div className="ww-neutral"><span className="ww-emblem ww-emblem-success"><Check size={32} /></span><h1>{ww.successTitle}</h1><p>{ww.successDescription}</p><button onClick={() => { setReference(""); setSelected("notes"); void engine.begin(); }}>{ww.newSession}</button></div>}
    </main>}

    {(view.phase === "editing" || view.phase === "lost" || view.phase === "conflict") && payload && <main className="ww-layout">
      <aside className="ww-rail" aria-label="טופסי המפגש">
        <div className="ww-rail-heading"><h2>{ww.title}</h2><p>{view.envelope ? dateTime(view.envelope.started_at) : ww.started}</p></div>
        <nav className="ww-items" aria-label="תוכן המפגש">
          {payload.items.map((entry, index) => <button key={entry.id} className={`ww-item ${selected === entry.id ? "active" : ""} ${showProblems && problems.includes(entry.id) ? "needs-attention" : ""}`} onClick={() => setSelected(entry.id)} aria-current={selected === entry.id ? "page" : undefined}><span>{titles[entry.type]}{entry.type !== "questionnaire" && <small> · {payload.items.slice(0, index + 1).filter((x) => x.type === entry.type).length}</small>}</span><small>{questionnaireFlags(entry)?.question9 ? ww.safetyShort : entry.completed_at && isFormComplete(entry) ? ww.completed : ww.incomplete}</small></button>)}
          <button className={`ww-item ${selected === "notes" ? "active" : ""}`} onClick={() => setSelected("notes")} aria-current={selected === "notes" ? "page" : undefined}><span>{ww.notes}</span><small>{payload.notes.trim() ? "נכתב" : "ריק"}</small></button>
        </nav>
        {view.phase === "editing" && <div className="ww-add-wrap"><button className="ww-add" onClick={() => setShowAdd((v) => !v)} aria-expanded={showAdd}><Plus size={18} />{ww.add}</button>{showAdd && <div className="ww-add-menu"><button disabled={payload.items.some((x) => x.type === "questionnaire")} onClick={() => add("questionnaire")}>{ww.addQuestion}</button><button onClick={() => add("diary_one")}>{ww.addDiaryOne}</button><button onClick={() => add("diary_two")}>{ww.addDiaryTwo}</button><button onClick={() => add("diary_three")}>{ww.addDiaryThree}</button></div>}<p className="ww-quiet">{ww.multiple}</p></div>}
        <div className="ww-rail-footer">{view.phase === "editing" && <><button className="ww-finish" onClick={startFinish}>{ww.finish}</button><button className="ww-text-button ww-danger-text" onClick={() => setDiscardOpen(true)}><Trash2 size={16} />{ww.discard}</button></>}</div>
      </aside>
      <div className="ww-work-area">
        {view.phase === "lost" && <div className="ww-banner" role="alert"><h2>{ww.lostTitle}</h2><p>{ww.lostDescription}</p><button onClick={() => void engine.begin(true)}>{ww.takeOver}</button><RecoveryCopy payload={payload} /></div>}
        {view.phase === "conflict" && <div className="ww-banner" role="alert"><h2>{ww.conflictTitle}</h2><p>{ww.conflictDescription}</p><button onClick={() => { if (window.confirm(ww.useServerConfirm)) void engine.useServerVersion(); }}>{ww.useServer}</button>{view.error === "workspace_in_use" && <button className="secondary" onClick={() => { if (window.confirm(ww.useServerConfirm)) void engine.useServerVersion(true); }}>{ww.takeOver}</button>}<RecoveryCopy payload={payload} /></div>}
        {view.phase === "editing" && view.reminderOpen && <div className="ww-banner ww-reminder" role="alert"><h2>{ww.hourQuestion}</h2><div className="ww-actions"><button className="secondary" onClick={() => engine.continueReminder()}>{ww.hourContinue}</button><button onClick={() => { engine.continueReminder(); startFinish(); }}>{ww.finish}</button></div></div>}
        <div className="ww-page-head"><div><h1>{item ? titles[item.type] : ww.notes}</h1><p>{item ? item.completed_at && isFormComplete(item) ? `${ww.completed} · ${dateTime(item.completed_at)}` : ww.incomplete : ww.notesHint}</p>{item && questionnaireFlags(item)?.question9 && <p className="ww-safety" role="alert">{ww.safetyShort}</p>}</div>{item && view.phase === "editing" && <button className="ww-text-button ww-danger-text" onClick={() => remove(item.id)}><Trash2 size={16} />{ww.remove}</button>}</div>
        {finishOpen && view.phase === "editing" && <section ref={finishRef} tabIndex={-1} className="ww-confirm" aria-label={ww.finishConfirm}><h2>{ww.finishConfirm}</h2><p>{ww.finishDescription}</p>{payload.items.some((entry) => questionnaireFlags(entry)?.question9) && <p className="ww-safety" role="alert">{ww.safety}</p>}<label htmlFor="reference-code">{ww.reference}</label><input id="reference-code" value={reference} maxLength={100} onChange={(e) => setReference(e.target.value)} /><p className="ww-quiet">{ww.referenceHelp}</p><div className="ww-actions"><button onClick={() => void doFinish()}>{ww.finish}</button><button className="secondary" onClick={() => setFinishOpen(false)}>{ww.cancel}</button></div></section>}
        {discardOpen && view.phase === "editing" && <section ref={discardRef} tabIndex={-1} className="ww-confirm ww-confirm-danger" aria-label={ww.discardConfirm}><h2>{ww.discardConfirm}</h2><p>{ww.discardDescription}</p><div className="ww-actions"><button onClick={() => void doDiscard()}>{ww.discard}</button><button className="secondary" onClick={() => setDiscardOpen(false)}>{ww.cancel}</button></div></section>}
        {showProblems && item && problems.includes(item.id) && <p className="ww-alert" role="alert">{ww.finishProblems}</p>}
        {view.error && <p className="ww-alert" role="alert">{message(view.error)}</p>}
        {view.phase === "editing" && view.error === "consent" && <section className="ww-confirm" aria-label={ww.consentTitle}><h2>{ww.consentTitle}</h2><p>{ww.consentDescription}</p><button onClick={() => { grantWorkspaceClinicalConsent(account); void engine.flush().catch(() => {}); }}>{ww.consentAction}</button></section>}
        {item ? <div className={view.phase !== "editing" ? "ww-readonly-editor" : ""}><WorksheetEditor key={item.id} item={item} onChange={editItem} disabled={view.phase !== "editing"} />{<WorksheetSave key={`save-${item.id}`} item={item} engine={engine} phase={view.phase} feedback={worksheetFeedback[item.id] ?? { status: "idle", submitted: "" }} setFeedback={(next) => { if (mounted.current) setWorksheetFeedback((previous) => ({ ...previous, [item.id]: next })); }} />}</div> : <section className="ww-sheet"><label htmlFor="session-notes">{ww.notes}</label><p className="ww-quiet">{ww.notesHint}</p><textarea id="session-notes" rows={16} value={payload.notes} disabled={view.phase !== "editing"} onChange={(event) => edit({ ...payload, notes: event.target.value })} maxLength={50000} /></section>}
        {view.phase === "editing" && view.save === "offline" && <button className="secondary" onClick={() => void engine.flush().catch(() => {})}>{ww.retrySave}</button>}
        {showProblems && problems.includes("empty") && <p className="ww-alert" role="alert">{ww.emptyProblem}</p>}
      </div>
    </main>}
  </div>;
}

function WorksheetEditor({ item, onChange, disabled }: { item: Worksheet; onChange: (next: Worksheet) => void; disabled: boolean }) {
  const d = item.data;
  const set = (key: string, value: unknown) => onChange(updateItem(item, { data: { [key]: value } }));
  if (item.type === "questionnaire") {
    const gad = Array.from({ length: 7 }, (_, i) => Array.isArray(d.gad7_answers) ? d.gad7_answers[i] ?? null : null) as (number | null)[];
    const phq = Array.from({ length: 9 }, (_, i) => Array.isArray(d.phq9_answers) ? d.phq9_answers[i] ?? null : null) as (number | null)[];
    return <div className="ww-sheet-stack"><section className="ww-sheet"><label htmlFor="measurement-date">{ww.date}</label><input id="measurement-date" type="date" value={item.measurement_date ?? ""} max={todayLocal()} disabled={disabled} onChange={(e) => onChange(updateItem(item, { measurement_date: e.target.value }))} /><div className="ww-scores" role="status" aria-live="polite"><ScoreSummary values={gad} kind="gad" /><ScoreSummary values={phq} kind="phq" /></div></section>
      {([mobile.gad7_questions, mobile.phq9_questions] as string[][]).map((questions, group) => <section className="ww-sheet" key={group}><h2>{group === 0 ? mobile.gad7_title : mobile.phq9_title}</h2><p>{group === 0 ? mobile.gad7_main_question : mobile.phq9_main_question}</p>{questions.map((question, index) => { const values = group === 0 ? gad : phq; return <fieldset className="ww-question" key={index} disabled={disabled}><legend>{index + 1}. {question}</legend><div className="ww-options">{mobile.answer_descriptions.map((label, value) => <label key={value} className={values[index] === value ? "selected" : ""}><input type="radio" name={`${item.id}-${group}-${index}`} checked={values[index] === value} onChange={() => set(group === 0 ? "gad7_answers" : "phq9_answers", values.map((answer, i) => i === index ? value : answer))} /><b>{value}</b><span>{label}</span></label>)}</div>{group === 1 && index === 8 && values[index] !== null && Number(values[index]) > 0 && <p className="ww-safety" role="alert">{ww.safety}</p>}</fieldset>; })}</section>)}
      <section className="ww-sheet"><fieldset disabled={disabled}><legend>{mobile.phq9_interference_question.replaceAll("**", "")}</legend><div className="ww-options ww-options-compact">{mobile.phq9_interference_options.map((label, value) => <label key={value} className={d.interference_level === value ? "selected" : ""}><input type="radio" name={`${item.id}-interference`} checked={d.interference_level === value} onChange={() => set("interference_level", value)} />{label}</label>)}</div></fieldset><label htmlFor={`${item.id}-note`}>{ww.optionalNote}</label><textarea id={`${item.id}-note`} rows={3} maxLength={50000} disabled={disabled} value={String(d.notes ?? "")} onChange={(e) => set("notes", e.target.value)} /></section>
    </div>;
  }
  const third = item.type === "diary_three";
  return <div className="ww-sheet-stack"><section className="ww-sheet"><label htmlFor={`${item.id}-event`}>{third ? ww.situation : ww.event}</label><textarea id={`${item.id}-event`} rows={4} maxLength={50000} disabled={disabled} value={String(d[third ? "situation" : "event"] ?? "")} onChange={(e) => set(third ? "situation" : "event", e.target.value)} /></section>
    {third ? <><ObjectList title={he.Diaries016} values={Array.isArray(d.automatic_thoughts) ? d.automatic_thoughts as Record<string, unknown>[] : []} fields={["text", "beliefBefore", "beliefAfter"]} labels={[ww.thought, ww.before, ww.after]} onChange={(v) => set("automatic_thoughts", v)} disabled={disabled} /><ObjectList title={he.Diaries017} values={Array.isArray(d.feelings) ? d.feelings as Record<string, unknown>[] : []} fields={["name", "intensityBefore", "intensityAfter"]} labels={[ww.name, ww.before, ww.after]} onChange={(v) => set("feelings", v)} disabled={disabled} /></> : <><StringList title={he.Diaries016} values={Array.isArray(d.automatic_thoughts) ? d.automatic_thoughts as string[] : []} onChange={(v) => set("automatic_thoughts", v)} disabled={disabled} /><ObjectList title={he.Diaries017} values={Array.isArray(d.feelings) ? d.feelings as Record<string, unknown>[] : []} fields={["name", "intensity"]} labels={[ww.name, ww.intensity]} onChange={(v) => set("feelings", v)} disabled={disabled} /></>}
    {item.type === "diary_one" ? <section className="ww-sheet"><label htmlFor={`${item.id}-behaviour`}>{ww.behaviour}</label><textarea id={`${item.id}-behaviour`} rows={3} maxLength={50000} disabled={disabled} value={String(d.behaviour ?? "")} onChange={(e) => set("behaviour", e.target.value)} /><label htmlFor={`${item.id}-symptoms`}>{ww.symptoms}</label><textarea id={`${item.id}-symptoms`} rows={2} maxLength={50000} disabled={disabled} value={String(d.physical_symptoms ?? "")} onChange={(e) => set("physical_symptoms", e.target.value)} /></section> : <><section className="ww-sheet"><h2>{he.Diaries020}</h2><div className="ww-errors">{thinkingErrors.map(([code, key]) => <label key={code}><input type="checkbox" disabled={disabled} checked={(Array.isArray(d.thinking_errors) ? d.thinking_errors as string[] : []).includes(code)} onChange={(e) => { const current = Array.isArray(d.thinking_errors) ? d.thinking_errors as string[] : []; const next = e.target.checked ? [...current, code] : current.filter((x) => x !== code); set("thinking_errors", next.length ? next : null); }} />{String((mobile as Record<string, unknown>)[key])}</label>)}<label className="ww-none"><input type="checkbox" disabled={disabled} checked={Array.isArray(d.thinking_errors) && d.thinking_errors.length === 0} onChange={(e) => set("thinking_errors", e.target.checked ? [] : null)} />{ww.thinkingNone}</label></div>{d.thinking_errors === null && <p className="ww-quiet">{ww.thinkingUnaddressed}</p>}</section>{third ? <ObjectList title={he.Diaries021} values={Array.isArray(d.alternative_thoughts) ? d.alternative_thoughts as Record<string, unknown>[] : []} fields={["text", "belief"]} labels={[ww.alternative, ww.belief]} onChange={(v) => set("alternative_thoughts", v)} disabled={disabled} /> : <StringList title={he.Diaries021} values={Array.isArray(d.alternative_thoughts) ? d.alternative_thoughts as string[] : []} onChange={(v) => set("alternative_thoughts", v)} disabled={disabled} />}</>}
  </div>;
}

function RecoveryCopy({ payload }: { payload: WorkspacePayload }) {
  return <details className="ww-recovery"><summary>{ww.localRecovery}</summary><p>{ww.localRecoveryHelp}</p><textarea readOnly aria-label={ww.localRecovery} value={JSON.stringify(payload, null, 2)} rows={12} dir="ltr" spellCheck={false} /></details>;
}

function StringList({ title, values, onChange, disabled }: { title: string; values: string[]; onChange: (next: string[]) => void; disabled: boolean }) {
  return <section className="ww-sheet"><h2>{title}</h2><div className="ww-rows">{values.map((value, index) => <div className="ww-row" key={index}><label className="ww-sr" htmlFor={`${title}-${index}`}>{title} {index + 1}</label><textarea id={`${title}-${index}`} rows={2} maxLength={50000} disabled={disabled} value={value} onChange={(e) => onChange(values.map((v, i) => i === index ? e.target.value : v))} /><button type="button" className="ww-icon-button" aria-label={`${ww.removeRow} ${index + 1}`} disabled={disabled || values.length <= 1} onClick={() => onChange(values.filter((_, i) => i !== index))}><Trash2 size={17} /></button></div>)}</div><button type="button" className="secondary" disabled={disabled || values.length >= 100} onClick={() => onChange([...values, ""])}><Plus size={16} />{ww.addRow}</button></section>;
}

function ObjectList({ title, values, fields, labels, onChange, disabled }: { title: string; values: Record<string, unknown>[]; fields: string[]; labels: string[]; onChange: (next: Record<string, unknown>[]) => void; disabled: boolean }) {
  const fresh = () => Object.fromEntries(fields.map((field, index) => [field, index === 0 ? "" : 0]));
  return <section className="ww-sheet"><h2>{title}</h2><div className="ww-rows">{values.map((value, index) => <fieldset className="ww-object-row" key={index} disabled={disabled}><legend>{title} {index + 1}</legend><div className="ww-object-fields">{fields.map((field, n) => <label key={field}>{labels[n]}{n === 0 ? <textarea rows={2} maxLength={50000} value={String(value[field] ?? "")} onChange={(e) => onChange(values.map((v, i) => i === index ? { ...v, [field]: e.target.value } : v))} /> : <input type="number" min="0" max="100" value={Number(value[field] ?? 0)} onChange={(e) => onChange(values.map((v, i) => i === index ? { ...v, [field]: e.target.value === "" ? null : Number(e.target.value) } : v))} />}</label>)}</div><button type="button" className="ww-text-button ww-danger-text" disabled={values.length <= 1} onClick={() => onChange(values.filter((_, i) => i !== index))}><Trash2 size={16} />{ww.removeRow}</button></fieldset>)}</div><button type="button" className="secondary" disabled={disabled || values.length >= 100} onClick={() => onChange([...values, fresh()])}><Plus size={16} />{ww.addRow}</button></section>;
}

function ScoreSummary({ values, kind }: { values: (number | null)[]; kind: "gad" | "phq" }) {
  const result = questionnaireScore(values, kind);
  return <div className={`ww-score ww-tone-${result.tone}`}><b dir="ltr">{kind === "gad" ? "GAD-7" : "PHQ-9"}</b>{result.total === null ? <span>{result.answered} מתוך {result.count} תשובות · השאלון טרם הושלם</span> : <><span>ציון כולל: <strong>{result.total}</strong> / {kind === "gad" ? 21 : 27}</span><span>{result.label}</span></>}</div>;
}

function WorksheetSave({ item, engine, phase, feedback, setFeedback }: { item: Worksheet; engine: WorkspaceEngine; phase: WorkspaceViewState["phase"]; feedback: WorksheetFeedback; setFeedback: (next: WorksheetFeedback) => void }) {
  const inFlight = useRef(false);
  const wording = JSON.stringify([item.data, item.measurement_date]);
  const diary = item.type !== "questionnaire";
  const complete = isFormComplete(item);
  const pending = feedback.status === "busy" && phase === "editing";
  const failed = feedback.status === "failed" || feedback.status === "busy" && phase !== "editing";
  const newer = feedback.submitted !== wording;
  const save = async () => {
    if (inFlight.current || feedback.status === "busy" || !complete || phase !== "editing") return;
    inFlight.current = true;
    setFeedback({ status: "busy", submitted: wording });
    try {
      await engine.saveWorksheet(item);
      setFeedback({ status: "saved", submitted: wording });
    } catch {
      setFeedback({ status: "failed", submitted: wording });
    } finally { inFlight.current = false; }
  };
  return <div className="ww-form-end"><div>
    {!complete && <p>{ww.formIncomplete}</p>}
    {failed && <p className="ww-tone-error" role="alert">{diary ? ww.diaryFailed : ww.formFailed}</p>}
    {feedback.status === "saved" && <p className={newer ? "ww-tone-warning" : "ww-tone-good"} role="status">{newer ? engine.state.save === "saved" ? ww.newerSaved : ww.earlierSaved : diary ? ww.diarySaved : ww.formSaved}</p>}
  </div><button aria-busy={pending} disabled={pending || !complete || phase !== "editing"} onClick={() => void save()}>{pending ? <RotateCw size={18} className="ww-spinner" /> : <Check size={18} />}{pending ? ww.savingEntry : failed ? ww.retrySave : ww.saveEntry}</button></div>;
}
