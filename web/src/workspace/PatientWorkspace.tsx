import { useEffect, useId, useRef, useState, type ReactNode } from 'react';
import { Link, NavLink, useNavigate, useParams, useLocation } from 'react-router-dom';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { BookOpen, CalendarDays, ExternalLink, Plus, Search, ChevronLeft, UserRound, AlertCircle } from 'lucide-react';
import { useAuth } from '../auth/Auth';
import { useWrite } from '../ui/hooks';
import { ConsentBoundary } from '../ui/ConsentBoundary';
import { DirtyGuard, ErrorBox, Loading, date, today } from '../ui/shared';
import { api, ApiError } from '../data/api';
import { canonical, patientDirectory, patientNames, verifyPatient, recordHistory, saveRecord, savePatientSession, type RecordRow } from '../data/patient-workspace';
import { createWorksheet, isFormComplete, type Worksheet, type WorksheetType } from './model';
import { WorksheetEditor } from './WorksheetEditor';
import copy from './patient-he.json';
import { questionnaireScore } from './scores';
import mobile from '../mobile-he.json';
import { ww } from './he';
import './patient-workspace.css';

const labels: Record<string,string> = {sessions:'מפגשים',questionnaire:'שאלונים',diary_one:'יומן מחשבות 1',diary_two:'יומן מחשבות 2',diary_three:'יומן מחשבות 3'};
export function NamesConsent({children}:{children:ReactNode}) {
  const {session,logout}=useAuth();
  return <ConsentBoundary account={session!.user.id} type="patient_name_storage" title={copy.nameTitle} description={copy.nameNotice} accept={copy.accept} decline={logout} declineLabel={copy.decline}>{children}</ConsentBoundary>;
}
export function PatientWorkspace({shared=false}:{shared?:boolean}) {
  const {session}=useAuth(), account=session!.user.id;
  const {patientId='',section='sessions'}=useParams();
  const navigate=useNavigate(), location=useLocation(), [search,setSearch]=useState('');
  const [privateChannel]=useState(()=>crypto.randomUUID()), [sharedName,setSharedName]=useState('');
  const opened=useRef(new Set<string>());
  const channel=shared?new URLSearchParams(location.search).get('view'):privateChannel;
  const directory=useQuery({queryKey:[account,'directory'],queryFn:patientDirectory,enabled:!shared});
  const names=useQuery({queryKey:[account,'server-names'],queryFn:()=>patientNames(account),enabled:!shared});
  const authorized=useQuery({queryKey:[account,shared?'shared-patient':'private-patient',patientId],queryFn:()=>verifyPatient(patientId),enabled:!!patientId});
  useEffect(()=>{
    if(!channel || (shared && !authorized.isSuccess))return;
    const bus=new BroadcastChannel(`cbtipul.shared-name.${channel}`);
    bus.onmessage=({data})=>{
      if(data?.account!==account)return;
      if(!shared && data?.kind==='request' && opened.current.has(data.patient)) {
        bus.postMessage({kind:'name',account,patient:data.patient,name:names.data?.[canonical(data.patient)]??'מטופל/ת ללא שם'});
      } else if(shared && data?.kind==='name' && data.patient===patientId && typeof data.name==='string') setSharedName(data.name);
    };
    if(shared)bus.postMessage({kind:'request',account,patient:patientId});
    return()=>bus.close();
  },[account,channel,shared,patientId,names.data,authorized.isSuccess]);
  const name=names.data?.[canonical(patientId)] ?? 'מטופל/ת ללא שם';
  const path=shared?`/shared/${patientId}`:`/patients/${patientId}`;
  const available=Object.entries(labels).filter(([key])=>!shared || key!=='sessions');
  if (shared && (!patientId || !available.some(([key])=>key===section))) return <main className="pw-neutral">התצוגה אינה זמינה.</main>;
  return <main className={`ww pw ${shared?'pw-shared':''}`} dir="rtl">
    {shared ? <header className="pw-share-header"><strong>CBTipul · תצוגה משותפת</strong><h1>{sharedName||"תיק המטופל/ת"}</h1>{!sharedName&&<p>השם זמין בפתיחת תצוגה משותפת מתוך החלון הפרטי.</p>}<p>שתפו ב־Zoom את החלון הזה בלבד, ולא את שולחן העבודה כולו.</p></header> : <>
      <header className="pw-heading"><div><h1>{patientId?name:'בחירת מטופל/ת'}</h1><p>עובדים יחד במפגש. שומרים ישירות בתיק המטופל/ת.</p></div>{patientId && <a className="button secondary" href={`${import.meta.env.BASE_URL}shared/${patientId}/diary_one?view=${privateChannel}`} onClick={()=>opened.current.add(patientId)} target="_blank" rel="noopener noreferrer"><ExternalLink size={18}/>תצוגה משותפת</a>}</header>
      <div className="pw-picker"><label><Search size={18}/>חיפוש מטופל/ת<input type="search" value={search} onChange={e=>setSearch(e.target.value)} placeholder="חיפוש לפי שם"/></label><label>מעבר למטופל/ת<select value={patientId} onChange={e=>navigate(e.target.value?`/patients/${e.target.value}/sessions`:'/')}><option value="">בחירת מטופל/ת</option>{directory.data?.filter(p=>p.id===patientId || !search || (names.data?.[canonical(p.id)]??'').includes(search)).map(p=><option key={p.id} value={p.id}>{names.data?.[canonical(p.id)]??'מטופל/ת ללא שם'}{p.active===false?' · לא פעיל/ה':''}</option>)}</select></label></div>
      {(directory.isPending||names.isPending)&&<Loading/>}{directory.isError&&<ErrorBox error={directory.error} retry={()=>void directory.refetch()}/>} {names.isError&&<ErrorBox error={names.error} retry={()=>void names.refetch()}/>}
      {!patientId&&directory.data&&<section aria-label="רשימת מטופלים" className="pw-directory">
        <div className="pw-list-caption"><strong>מטופלים</strong><span>{directory.data.length} בתיק</span></div>
        <ul className="pw-record-list">{directory.data.filter(p=>!search || (names.data?.[canonical(p.id)]??'').includes(search)).sort((a,b)=>(names.data?.[canonical(a.id)]??'').localeCompare(names.data?.[canonical(b.id)]??'','he')).map(p=><li key={p.id}><Link className="pw-list-row pw-patient-row" to={`/patients/${p.id}/sessions`}><UserRound size={22} aria-hidden="true"/><strong>{names.data?.[canonical(p.id)]??'מטופל/ת ללא שם'}</strong><span className="pw-record-meta">{p.active===false?'לא פעיל/ה':'פעיל/ה'}</span><ChevronLeft size={18} aria-hidden="true"/></Link></li>)}</ul>
        {directory.data.length===0?<p className="pw-list-empty">אין עדיין מטופלים בתיק. ניתן להוסיף מטופלים באפליקציה.</p>:search&&!directory.data.some(p=>(names.data?.[canonical(p.id)]??'').includes(search))&&<p className="pw-list-empty" role="status">לא נמצאו מטופלים בחיפוש זה.</p>}
      </section>}
    </>}
    {patientId && (authorized.isPending?<Loading/>:authorized.isError?<ErrorBox error={authorized.error} retry={()=>void authorized.refetch()}/>:<>
      <nav className="pw-tabs" aria-label="כלים בתיק">{available.map(([key,title])=><NavLink key={key} to={`${path}/${key}${shared?location.search:""}`}>{key==='sessions'?<CalendarDays size={17}/>:<BookOpen size={17}/>} {title}</NavLink>)}</nav>
      {section==='sessions'&&!shared ? <PatientSessions key={`${account}:${patientId}`} patient={patientId}/> : available.some(([key])=>key===section) ? <Records key={`${account}:${patientId}:${section}:${shared}`} patient={patientId} type={section as WorksheetType} shared={shared}/> : <p>העמוד אינו זמין.</p>}
    </>)}
  </main>;
}
function EditorDialog({title,closeLabel,busy,onClose,children}:{title:string;closeLabel:string;busy:boolean;onClose:()=>void;children:ReactNode}) {
  const ref=useRef<HTMLDialogElement>(null), heading=useRef<HTMLHeadingElement>(null), id=useId();
  useEffect(()=>{
    const dialog=ref.current!, trigger=document.activeElement as HTMLElement|null;
    dialog.showModal();heading.current?.focus();
    const overflow=document.body.style.overflow;document.body.style.overflow='hidden';
    return()=>{dialog.close();document.body.style.overflow=overflow;if(trigger?.isConnected)trigger.focus();};
  },[]);
  return <dialog ref={ref} className="pw-modal" aria-labelledby={id} aria-busy={busy} dir="rtl" onCancel={e=>{e.preventDefault();if(!busy)onClose();}}>
    <header className="pw-modal-heading"><h2 id={id} ref={heading} tabIndex={-1}>{title}</h2><button className="secondary" disabled={busy} onClick={onClose}>{closeLabel}</button></header>
    <div className="pw-modal-body">{children}</div>
  </dialog>;
}
function ProcessingConsent({children}:{children:ReactNode}) {
  const {session}=useAuth();
  return <ConsentBoundary account={session!.user.id} type="clinical_text_processing" title={ww.consentTitle} description={ww.consentDescription} accept={ww.consentAction} decline={async()=>{}}>{children}</ConsentBoundary>;
}
function useSaveState(patient: string) {
  const {session}=useAuth(), account=session!.user.id, client=useQueryClient();
  const [busy,setBusy]=useState(false),[error,setError]=useState<unknown>(null),[saved,setSaved]=useState(false),[uncertain,setUncertain]=useState(false);
  const alive=useRef(true), running=useRef(false);
  useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
  async function run(action:()=>Promise<RecordRow>, accept:(row:RecordRow)=>void) {
    if(running.current||uncertain)return;
    running.current=true;setBusy(true);setError(null);setSaved(false);
    try {const row=await action();if(alive.current){accept(row);setSaved(true);void client.invalidateQueries({predicate:q=>q.queryKey[0]===account&&q.queryKey.includes(patient)});}}
    catch(e){if(alive.current){setError(e);if(e instanceof ApiError&&e.code==='uncertain_create')setUncertain(true);}}
    finally{running.current=false;if(alive.current)setBusy(false);}
  }
  return {busy,error,saved,uncertain,run,changed:()=>setSaved(false),reset:()=>{setUncertain(false);setError(null);setSaved(false);},retryAfterCheck:()=>{setUncertain(false);setError(null);}};
}
function SaveFeedback({state,onInspect}:{state:ReturnType<typeof useSaveState>;onInspect:()=>void}) {
  return <>{state.saved&&<p className="success" role="status">הרשומה נשמרה בתיק המטופל/ת</p>}{state.uncertain?<section className="notice" role="alert"><p>לא ניתן לוודא אם הרשומה נשמרה. התוכן נשאר פתוח בחלון זה. בדקו את ההיסטוריה לפני ניסיון נוסף — שמירה נוספת עלולה ליצור כפילות.</p><button type="button" className="secondary" onClick={onInspect}>בדיקת ההיסטוריה</button> <button type="button" className="secondary" onClick={()=>{if(window.confirm('בדקתם את ההיסטוריה? ניסיון שמירה נוסף עלול ליצור רשומה כפולה.'))state.retryAfterCheck();}}>בדקתי — לאפשר ניסיון נוסף</button></section>:state.error?<ErrorBox error={state.error}/>:null}</>;
}
function Records({patient,type,shared}:{patient:string;type:WorksheetType;shared:boolean}) {
  const {session}=useAuth(), write=useWrite(), account=session!.user.id;
  const history=useQuery({queryKey:[account,shared?'shared-records':'private-records',patient,type],queryFn:()=>recordHistory(patient,type,shared)});
  const [edit,setEdit]=useState<{item:Worksheet;id:string|null;original:RecordRow|null}|null>(null);
  const [baseline,setBaseline]=useState(''),[notes,setNotes]=useState<unknown>(undefined),[target,setTarget]=useState<string>('');
  const [showHistory,setShowHistory]=useState(false);
  const HistoryContainer=type==='questionnaire'?'section':'details';
  const state=useSaveState(patient);
  const sessions=useQuery({queryKey:[account,'session-choices',patient],queryFn:()=>api.sessions(patient),enabled:!shared&&type==='questionnaire'});
  const fingerprint=edit?JSON.stringify([edit.item,notes,target]):'';
  const dirty=!!edit && fingerprint!==baseline;
  const canReplace=()=>!state.busy&&(!dirty||window.confirm('יש שינויים שלא נשמרו. לוותר עליהם?'));
  function open(row?:RecordRow) {
    if(!canReplace())return;
    const item=row?{id:String(row.id),type,data:{...row},measurement_date:typeof row.answered_date==='string'?row.answered_date:undefined}:createWorksheet(type);
    if(type==='questionnaire')delete item.data.notes;
    const value=!shared&&row?row.combined_notes:undefined;
    const link=String(row?.session_id??'');
    setShowHistory(false);setNotes(value);setTarget(link);setEdit({item,id:row?String(row.id):null,original:row??null});setBaseline(JSON.stringify([item,value,link]));state.reset();
  }
  async function save() {
    if(!edit)return;
    const submitted=edit;
    await state.run(()=>saveRecord(patient,submitted.id,submitted.item,shared,target||null,notes===submitted.original?.combined_notes?undefined:notes),row=>{
      const item={...submitted.item,id:String(row.id)};
      setEdit({item,id:String(row.id),original:row});setBaseline(JSON.stringify([item,notes,target]));
    });
  }
  return <><DirtyGuard dirty={dirty||state.busy} busy={state.busy}/><div className="pw-section-heading"><div><h2>{labels[type]}</h2><p>{type==='questionnaire'?'שאלונים בתיק המטופל/ת ובמפגשים':'כל הרשומות, כולל רשומות שמולאו באפליקציה ובמפגש'}</p></div><button disabled={!write||state.busy||state.uncertain} onClick={()=>open()}><Plus size={18}/>{type==='questionnaire'?'שאלון חדש':'רשומה חדשה'}</button></div>
    {history.isPending?<Loading/>:history.isError?<ErrorBox error={history.error} retry={()=>void history.refetch()}/>:<HistoryContainer {...(type==='questionnaire'?{}:{open:!edit||showHistory})} className="pw-history">{type==='questionnaire'?<h3 className="pw-history-title">היסטוריה · {history.data.length} רשומות</h3>:<summary onClick={e=>{e.preventDefault();setShowHistory(v=>!v);}}>היסטוריה · {history.data.length} רשומות</summary>}<ul className="pw-record-list">{history.data.length===0?<li className="pw-list-empty">אין עדיין רשומות.</li>:history.data.map(row=><li key={String(row.id)}><button className={`pw-list-row ${type==='questionnaire'?'pw-questionnaire-row':'pw-diary-row'}`} aria-current={edit?.id===String(row.id)?'true':undefined} disabled={state.busy} onClick={()=>open(row)}><RecordSummary row={row} type={type}/><ChevronLeft size={18} aria-hidden="true"/></button></li>)}</ul></HistoryContainer>}
    {edit&&type==='questionnaire'&&showHistory&&<button className="secondary" onClick={()=>setShowHistory(false)}>חזרה לשאלון הפתוח</button>}
    {edit&&(type!=='questionnaire'||!showHistory)&&<RecordEditorFrame type={type} isNew={!edit.id} busy={state.busy} onClose={()=>{if(canReplace()){setEdit(null);state.reset();}}}><section className="pw-editor">{edit.id && history.data?.some(row=>String(row.id)===edit.id&&JSON.stringify(row)!==JSON.stringify(edit.original))&&<p className="notice">קיימים נתונים עדכניים בהיסטוריה. <button className="text-button" disabled={state.busy} onClick={()=>open(history.data?.find(row=>String(row.id)===edit.id))}>טעינת הרשומה מחדש</button></p>}<div className="pw-section-heading"><h3>{type==='questionnaire'?'תשובות וציונים':edit.id?'עריכת הרשומה':'רשומה חדשה'}</h3><span>{edit.original?date(String(edit.original.created_at??edit.original.answered_date??'')):''}</span></div>
      {type==='questionnaire'&&!shared&&<label>שיוך למפגש{edit.id?<p>{target?date(sessions.data?.find(s=>String(s.id)===target)?.session_date):'ללא מפגש'}</p>:<select value={target} disabled={state.busy} onChange={e=>{setTarget(e.target.value);state.changed();}}><option value="">ללא מפגש</option>{sessions.data?.map(s=><option value={String(s.id)} key={s.id}>{date(s.session_date)}</option>)}</select>}</label>}
      <WorksheetEditor item={edit.item} shared onChange={item=>{setEdit({...edit,item});state.changed();}} disabled={!write||state.busy}/>
      {type==='questionnaire'&&!shared&&<details className="pw-private-notes"><summary>הערות פרטיות למטפל/ת — אינן מוצגות בחלון השיתוף</summary><QuestionnaireNotes value={notes} disabled={!write||state.busy} onChange={value=>{setNotes(value);state.changed();}}/></details>}
      <SaveFeedback state={state} onInspect={()=>{setShowHistory(true);void history.refetch();}}/>
      {type==='questionnaire'&&!shared&&notes!==undefined&&notes!==edit.original?.combined_notes?<ProcessingConsent><SaveButton state={state} valid={write&&isFormComplete(edit.item)} save={save}/></ProcessingConsent>:<SaveButton state={state} valid={write&&isFormComplete(edit.item)} save={save}/>}
      {!isFormComplete(edit.item)&&<p className="pw-hint">יש להשלים את השדות הנדרשים לפני השמירה.</p>}
    </section></RecordEditorFrame>}</>;
}
function RecordEditorFrame({type,isNew,busy,onClose,children}:{type:WorksheetType;isNew:boolean;busy:boolean;onClose:()=>void;children:ReactNode}) {
  return type==='questionnaire'?<EditorDialog title={isNew?'שאלון חדש':'עריכת שאלון'} closeLabel={isNew?'ביטול':'חזרה לשאלונים'} busy={busy} onClose={onClose}>{children}</EditorDialog>:<>{children}</>;
}
function RecordSummary({row,type}:{row:RecordRow;type:WorksheetType}) {
  const author=row.created_by==='patient'?'מולא על ידי המטופל/ת':'מולא על ידי המטפל/ת';
  if(type==='questionnaire') {
    const gad=questionnaireScore(Array.isArray(row.gad7_answers)?row.gad7_answers:[], 'gad');
    const phq=questionnaireScore(Array.isArray(row.phq9_answers)?row.phq9_answers:[], 'phq');
    const flagged=Array.isArray(row.phq9_answers)&&Number(row.phq9_answers[8])>0;
    return <><span className="pw-record-date"><strong>{date(typeof row.answered_date==='string'?row.answered_date:null)}</strong><small>תאריך המדידה</small></span><span className="pw-list-scores">{[['GAD-7',gad],['PHQ-9',phq]].map(([name,result])=>{const score=result as typeof gad;return <span key={String(name)}><b dir="ltr">{String(name)}</b><strong>{score.total??`${score.answered}/${score.count}`}</strong><small>{score.total===null?'תשובות · טרם הושלם':score.label}</small></span>;})}</span><span className="pw-record-meta">{row.session_id!=null?'משויך למפגש':'ללא מפגש'}<small>{author}</small>{flagged&&<span className="pw-list-flag"><AlertCircle size={15} aria-hidden="true"/>לתשומת לב: שאלה 9</span>}</span></>;
  }
  const event=String(row[type==='diary_three'?'situation':'event']??'');
  const feelings=Array.isArray(row.feelings)?row.feelings.map(f=>typeof f?.name==='string'?f.name:'').filter(Boolean):[];
  return <><span className="pw-record-date"><strong>{date(String(row.created_at??''))}</strong><small>{author}</small></span><span className="pw-record-content"><span className="pw-record-preview">{event||'ללא תיאור אירוע'}</span>{feelings.length>0&&<small className="pw-record-meta">{feelings.join(' · ')}</small>}</span></>;
}
function SaveButton({state,valid,save}:{state:ReturnType<typeof useSaveState>;valid:boolean;save:()=>Promise<void>}) {
  return <div className="pw-save"><button disabled={!valid||state.busy||state.uncertain} aria-busy={state.busy} onClick={()=>void save()}>{state.busy?'שומר…':state.error?'ניסיון שמירה נוסף':'שמירה בתיק המטופל/ת'}</button><small>השמירה מאושרת לאחר קבלת תשובת השרת.</small></div>;
}
function QuestionnaireNotes({value,onChange,disabled}:{value:unknown;onChange:(v:unknown)=>void;disabled:boolean}) {
  const obj=value&&typeof value==='object'&&!Array.isArray(value)?value as Record<string,unknown>:{};
  return <>{(['gad7','phq9'] as const).map((key)=><div key={key}><h4>{key==='gad7'?'GAD-7':'PHQ-9'}</h4>{(key==='gad7'?mobile.gad7_questions:mobile.phq9_questions).map((text,i)=><label key={i}>{text}<textarea rows={2} disabled={disabled} value={Array.isArray(obj[key])?String(obj[key][i]??''):''} onChange={e=>onChange({...obj,[key]:Array.from({length:key==='gad7'?7:9},(_,n)=>n===i?e.target.value:Array.isArray(obj[key])?obj[key][n]??'':'')})}/></label>)}</div>)}<label>הערה על מידת ההפרעה<textarea rows={2} disabled={disabled} value={String(obj.interference??'')} onChange={e=>onChange({...obj,interference:e.target.value})}/></label></>;
}
function PatientSessions({patient}:{patient:string}) {
  const {session}=useAuth(),write=useWrite();
  const history=useQuery({queryKey:[session!.user.id,'record-sessions',patient],queryFn:()=>api.sessions(patient)});
  const [draft,setDraft]=useState<{id:string|null;day:string;type:string;notes:string;original?:string}|null>(null),[baseline,setBaseline]=useState(''),[inspect,setInspect]=useState(false);
  const state=useSaveState(patient),dirty=!!draft&&JSON.stringify(draft)!==baseline;
  function open(d:NonNullable<typeof draft>) {if(state.busy||(dirty&&!window.confirm('יש שינויים שלא נשמרו. לוותר עליהם?')))return;setInspect(false);setDraft(d);setBaseline(JSON.stringify(d));state.reset();}
  async function save(){if(!draft)return;const snapshot=draft;await state.run(()=>savePatientSession(patient,snapshot.id,snapshot.day,snapshot.type,snapshot.notes,snapshot.original),row=>{const next={...snapshot,id:String(row.id),original:String(row.notes??'')};setDraft(next);setBaseline(JSON.stringify(next));});}
  return <><DirtyGuard dirty={dirty||state.busy} busy={state.busy}/><div className="pw-section-heading"><h2>מפגשים וסיכומים</h2><button disabled={!write||state.busy||state.uncertain} onClick={()=>open({id:null,day:today(),type:'',notes:''})}><Plus size={18}/>מפגש חדש</button></div>
    {history.isPending?<Loading/>:history.isError?<ErrorBox error={history.error} retry={()=>void history.refetch()}/>:<ul className="pw-session-list pw-record-list" aria-label="רשימת מפגשים">{history.data.length===0&&<li className="pw-list-empty">אין עדיין מפגשים.</li>}{history.data.map(s=><li key={s.id}><button className="pw-list-row pw-session-row" aria-current={draft?.id===String(s.id)?'true':undefined} disabled={state.busy} onClick={()=>open({id:String(s.id),day:s.session_date.slice(0,10),type:s.type??'',notes:s.notes??'',original:s.notes??''})}><span className="pw-record-date"><strong>{date(s.session_date)}</strong><small>{s.type==='core_belief_challenge'?copy.coreBeliefChallenge:(mobile as Record<string,unknown>)[`session_type_${s.type}`] as string??'מפגש'}</small></span><span className={`pw-record-preview ${s.notes?'':'pw-record-meta'}`}>{s.notes||'עדיין אין סיכום למפגש'}</span><span className="pw-record-action">פתיחת המפגש</span><ChevronLeft size={18} aria-hidden="true"/></button></li>)}</ul>}

    {draft&&inspect&&<button className="secondary" onClick={()=>setInspect(false)}>חזרה למפגש הפתוח</button>}
    {draft&&!inspect&&<EditorDialog title={draft.id?'עריכת מפגש':'מפגש חדש'} closeLabel={draft.id?'חזרה למפגשים':'ביטול'} busy={state.busy} onClose={()=>{if(!state.busy&&(!dirty||window.confirm('יש שינויים שלא נשמרו. לוותר עליהם?'))){setDraft(null);state.reset();}}}><section className="pw-session-editor"><div className="form-row"><label>תאריך המפגש<input type="date" required value={draft.day} disabled={!write||state.busy} onChange={e=>{setDraft({...draft,day:e.target.value});state.changed();}}/></label><label>סוג המפגש<select disabled={!write||state.busy} value={draft.type} onChange={e=>{setDraft({...draft,type:e.target.value});state.changed();}}><option value="">ללא סוג</option><option value="core_belief_challenge">{copy.coreBeliefChallenge}</option>{Object.entries(mobile).filter(([key,v])=>key.startsWith('session_type_')&&!['session_type_label','session_type_none'].includes(key)&&typeof v==='string').map(([key,v])=><option key={key} value={key.replace('session_type_','')}>{v as string}</option>)}</select></label></div><label htmlFor="patient-session-summary">סיכום הפגישה<textarea id="patient-session-summary" aria-label="סיכום הפגישה" rows={8} maxLength={50000} value={draft.notes} disabled={!write||state.busy} onChange={e=>{setDraft({...draft,notes:e.target.value});state.changed();}}/></label><p className="pw-hint">הסיכום עובר הסרת פרטים מזהים לפני שמירה. שינוי הסיכום מחייב יצירה מחדש של הניתוח המובנה באפליקציה.</p><SaveFeedback state={state} onInspect={()=>{setInspect(true);void history.refetch();}}/><ProcessingConsent><SaveButton state={state} valid={write&&!!draft.day} save={save}/></ProcessingConsent></section></EditorDialog>}
  </>;
}
