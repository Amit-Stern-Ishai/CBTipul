import {DiaryReading} from './DiaryReading';
import { useEffect, useEffectEvent, useId, useRef, useState, type ReactNode } from 'react';
import { Link, NavLink, useNavigate, useParams, useLocation } from 'react-router-dom';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { BookOpen, CalendarDays, Monitor, Plus, Search, ChevronLeft, UserRound, AlertCircle, ClipboardList } from 'lucide-react';
import { names as displayNames } from '../domain/privacy';
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
import './patient-guide.css';
import './shared-workspace.css';
import {CoreBeliefEditor} from './CoreBeliefEditor';
import {ConceptualizationEditor} from './ConceptualizationEditor';
import {PatientTimeline} from './PatientTimeline';

const labels: Record<string,string> = {core_belief:'ערעור אמונת יסוד',conceptualization:'המשגה',sessions:'פגישות',questionnaire:'שאלונים',diary_one:'יומן מחשבות 1',diary_two:'יומן מחשבות 2',diary_three:'יומן מחשבות 3'};
export function NamesConsent({children}:{children:ReactNode}) {
  const {session,logout}=useAuth();
  return <ConsentBoundary account={session!.user.id} type="patient_name_storage" title={copy.nameTitle} description={copy.nameNotice} accept={copy.accept} decline={logout} declineLabel={copy.decline}>{children}</ConsentBoundary>;
}
type DraftStateListener=(state:{dirty:boolean;busy:boolean})=>void;
export function PatientWorkspace({shared=false,onDraftState}:{shared?:boolean;onDraftState?:DraftStateListener}) {
  const {session}=useAuth(), account=session!.user.id;
  const {patientId='',section='sessions'}=useParams();
  const navigate=useNavigate(), location=useLocation(), [search,setSearch]=useState('');
  const directory=useQuery({queryKey:[account,'directory'],queryFn:patientDirectory,enabled:!shared});
  const names=useQuery({queryKey:[account,'server-names'],queryFn:()=>patientNames(account),enabled:!shared,staleTime:Infinity});
  useEffect(()=>{if(names.data)Object.entries(names.data).forEach(([id,name])=>displayNames.set(localStorage,account,id,name));},[account,names.data]);
  const authorized=useQuery({queryKey:[account,shared?'shared-patient':'private-patient',patientId],queryFn:()=>verifyPatient(patientId),enabled:!!patientId});
  const namesReady=names.isSuccess;
  const name=namesReady?(names.data[canonical(patientId)] ?? 'מטופל/ת ללא שם'):(names.isError?'השם אינו זמין':'טוענים שם…');
  const path=shared?`/shared/${patientId}`:`/patients/${patientId}`;
  const available=Object.entries(labels).filter(([key])=>!shared || key!=='sessions');
  const sharedName=location.state?.patient===patientId&&location.state?.account===account?location.state.name:'';
  const sharingState={patient:patientId,account,name:shared?sharedName:name};
  if (shared && (!patientId || !available.some(([key])=>key===section))) return <main className="pw-neutral">התצוגה אינה זמינה.</main>;
  return <main className={`ww pw ${shared?'pw-shared':patientId?'pw-patient-guide':'pw-directory-guide'} ${!shared&&section==='overview'?'pw-overview':''}`} dir="rtl">
    {shared ? <header className="pw-share-header"><div><Monitor size={22}/><strong>מרחב הפגישה · לשיתוף מסך</strong><h1>{sharedName||'עובדים יחד'}</h1></div><Link className="secondary button" to={`/patients/${patientId}/overview`}>יציאה לתיק הפרטי</Link></header> : <>
      {section!=='overview'&&<><header className="pw-heading"><div>{patientId&&<Link className="pw-back" to="/">כל המטופלים</Link>}<h1>{patientId?name:'בחירת מטופל/ת'}</h1><p>{patientId?"התיק הטיפולי · פגישות, שאלונים ויומני מחשבות":"עובדים יחד בפגישה. שומרים ישירות בתיק המטופל/ת."}</p></div>{patientId && <Link className="button" state={{patient:patientId,account,name}} to={`/shared/${patientId}/questionnaire`}>התחלת פגישה כעת</Link>}</header>
      <div className="pw-picker"><label><Search size={18}/>חיפוש מטופל/ת<input type="search" value={search} onChange={e=>setSearch(e.target.value)} placeholder="חיפוש לפי שם"/></label><label>מעבר למטופל/ת<select disabled={!namesReady || !directory.isSuccess} aria-busy={!namesReady} value={patientId} onChange={e=>navigate(e.target.value?`/patients/${e.target.value}/overview`:'/')}><option value="">{names.isError?"טעינת השמות נכשלה":!namesReady?"טוענים שמות…":"בחירת מטופל/ת"}</option>{namesReady && directory.data?.filter(p=>p.id===patientId || !search || (names.data?.[canonical(p.id)]??'').includes(search)).map(p=><option key={p.id} value={p.id}>{names.data?.[canonical(p.id)]??'מטופל/ת ללא שם'}{p.active===false?' · לא פעיל/ה':''}</option>)}</select></label></div>
      </>}
      {(directory.isPending||names.isPending)&&<Loading/>}{directory.isError&&<ErrorBox error={directory.error} retry={()=>void directory.refetch()}/>} {names.isError&&<ErrorBox error={names.error} retry={()=>void names.refetch()}/>}
      {!patientId&&namesReady&&directory.data&&<section aria-label="רשימת מטופלים" className="pw-directory">
        <div className="pw-list-caption"><strong>מטופלים</strong><span>{directory.data.length} בתיק</span></div>
        <ul className="pw-record-list">{directory.data.filter(p=>!search || (names.data?.[canonical(p.id)]??'').includes(search)).sort((a,b)=>(names.data?.[canonical(a.id)]??'').localeCompare(names.data?.[canonical(b.id)]??'','he')).map(p=><li key={p.id}><Link className="pw-list-row pw-patient-row" to={`/patients/${p.id}/overview`}><UserRound size={22} aria-hidden="true"/><strong>{names.data?.[canonical(p.id)]??'מטופל/ת ללא שם'}</strong><span className="pw-record-meta">{p.active===false?'לא פעיל/ה':'פעיל/ה'}</span><ChevronLeft size={18} aria-hidden="true"/></Link></li>)}</ul>
        {directory.data.length===0?<p className="pw-list-empty">אין עדיין מטופלים בתיק. ניתן להוסיף מטופלים באפליקציה.</p>:search&&!directory.data.some(p=>(names.data?.[canonical(p.id)]??'').includes(search))&&<p className="pw-list-empty" role="status">לא נמצאו מטופלים בחיפוש זה.</p>}
      </section>}
    </>}
    {patientId && (authorized.isPending?<Loading/>:authorized.isError?<ErrorBox error={authorized.error} retry={()=>void authorized.refetch()}/>:<>
      {!shared&&section==='overview'?<PatientTimeline key={`${account}:${patientId}`} patient={patientId} name={name} />:<div className="pw-clinical-layout"><nav className="pw-tabs" aria-label="כלים בתיק">{!shared&&<NavLink to={`${path}/overview`}>התיק הטיפולי</NavLink>}{available.map(([key,title])=><NavLink key={key} data-category={key==='sessions'?'session':key==='questionnaire'?'questionnaire':'diary'} to={`${path}/${key}`} state={shared?sharingState:undefined}>{key==='sessions'?<CalendarDays size={20}/>:key==='questionnaire'?<ClipboardList size={20}/>:<BookOpen size={20}/>} {title}</NavLink>)}</nav>
      <div className="pw-clinical-content">{section==='core_belief'?<CoreBeliefEditor key={`${account}:${patientId}:${shared}`} patient={patientId} shared={shared} onDraftState={onDraftState}/>:section==='conceptualization'?<ConceptualizationEditor key={`${account}:${patientId}:${shared}`} patient={patientId} shared={shared} onDraftState={onDraftState}/>:section==='sessions'&&!shared ? <PatientSessions key={`${account}:${patientId}`} patient={patientId}/> : available.some(([key])=>key===section) ? <Records key={`${account}:${patientId}:${section}:${shared}`} patient={patientId} type={section as WorksheetType} shared={shared} onDraftState={onDraftState}/> : <p>העמוד אינו זמין.</p>}</div></div>}
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
    catch(e){if(alive.current){setError(e);if(e instanceof ApiError&&['uncertain_create','save_outcome_unknown'].includes(e.code))setUncertain(true);}}
    finally{running.current=false;if(alive.current)setBusy(false);}
  }
  return {busy,error,saved,uncertain,run,changed:()=>setSaved(false),reset:()=>{setUncertain(false);setError(null);setSaved(false);},retryAfterCheck:()=>{setUncertain(false);setError(null);}};
}
function SaveFeedback({state,onInspect}:{state:ReturnType<typeof useSaveState>;onInspect:()=>void}) {
  return <>{state.saved&&<p className="success" role="status">הרשומה נשמרה בתיק המטופל/ת</p>}{state.uncertain?<section className="notice" role="alert"><p>לא ניתן לוודא אם הרשומה נשמרה. התוכן נשאר פתוח בחלון זה. בדקו את ההיסטוריה לפני ניסיון נוסף — שמירה נוספת עלולה ליצור כפילות.</p><button type="button" className="secondary" onClick={onInspect}>בדיקת ההיסטוריה</button> <button type="button" className="secondary" onClick={()=>{if(window.confirm('בדקתם את ההיסטוריה? ניסיון שמירה נוסף עלול ליצור רשומה כפולה.'))state.retryAfterCheck();}}>בדקתי — לאפשר ניסיון נוסף</button></section>:state.error instanceof ApiError&&state.error.code==='record_changed'?<section className="notice" role="alert"><p>הרשומה השתנתה מאז שנפתחה. השינויים שלכם נשארו במסך. בדקו את הרשומה המעודכנת לפני שמירה נוספת.</p><button className="secondary" onClick={onInspect}>בדיקת הרשומה המעודכנת</button></section>:state.error?<ErrorBox error={state.error}/>:null}</>;
}
function Records({patient,type,shared,onDraftState}:{patient:string;type:WorksheetType;shared:boolean;onDraftState?:DraftStateListener}) {
  const {session}=useAuth(), write=useWrite(), account=session!.user.id;
  const history=useQuery({queryKey:[account,shared?'shared-records':'private-records',patient,type],queryFn:()=>recordHistory(patient,type,shared)});
  const [edit,setEdit]=useState<{item:Worksheet;id:string|null;original:RecordRow|null}|null>(null);
  const [baseline,setBaseline]=useState(''),[notes,setNotes]=useState<unknown>(undefined),[target,setTarget]=useState<string>('');
  const [showHistory,setShowHistory]=useState(false);
  const [editing,setEditing]=useState(false);
  const editorRoot=useRef<HTMLElement>(null);
  useEffect(()=>{if(type==='questionnaire')return;const frame=requestAnimationFrame(()=>{const target=editorRoot.current?.querySelector<HTMLElement>(editing?'textarea':'h3');if(target?.matches('h2,h3'))target.setAttribute('tabindex','-1');target?.focus({preventScroll:true});});return()=>cancelAnimationFrame(frame);},[editing,edit?.id,type]);
  const HistoryContainer=shared?'details':type==='questionnaire'?'section':'details';
  const state=useSaveState(patient);
  const requested=new URLSearchParams(useLocation().search), requestedEntry=requested.get('entry'), requestedNew=requested.has('new');
  const consumed=useRef(false);
  const requestedOpen=useEffectEvent(()=>{if(consumed.current||!history.isSuccess)return;consumed.current=true;if(requestedNew)open();else if(requestedEntry){const row=history.data.find(r=>String(r.id)===requestedEntry);if(row)open(row);}});
  useEffect(()=>{requestedOpen();},[history.isSuccess,requestedEntry,requestedNew]);
  const sessions=useQuery({queryKey:[account,'session-choices',patient],queryFn:()=>api.sessions(patient),enabled:!shared&&type==='questionnaire'});
  const fingerprint=edit?JSON.stringify([edit.item,notes,target]):'';
  const dirty=!!edit && fingerprint!==baseline;
  useEffect(()=>{onDraftState?.({dirty:dirty||state.busy,busy:state.busy});return()=>onDraftState?.({dirty:false,busy:false});},[onDraftState,dirty,state.busy]);
  const editable=write && !(type==='questionnaire' && edit?.original?.created_by==='patient');
  const canReplace=()=>!state.busy&&(!dirty||window.confirm('יש שינויים שלא נשמרו. לוותר עליהם?'));
  function open(row?:RecordRow) {
    if(!canReplace())return;
    const item=row?{id:String(row.id),type,data:{...row},measurement_date:typeof row.answered_date==='string'?row.answered_date:undefined}:createWorksheet(type);
    if(type==='questionnaire')delete item.data.notes;
    const value=!shared&&row?row.combined_notes:undefined;
    const link=String(row?.session_id??'');
    setEditing(!row||type==='questionnaire');setShowHistory(false);setNotes(value);setTarget(link);setEdit({item,id:row?String(row.id):null,original:row??null});setBaseline(JSON.stringify([item,value,link]));state.reset();
  }
  async function save() {
    if(!edit)return;
    const submitted=edit;
    await state.run(()=>saveRecord(patient,submitted.id,submitted.item,shared,target||null,notes===submitted.original?.combined_notes?undefined:notes,submitted.original),row=>{
      const item={...submitted.item,id:String(row.id),data:{...row}};
      if(type!=='questionnaire')setEditing(false);
      setEdit({item,id:String(row.id),original:row});setBaseline(JSON.stringify([item,notes,target]));
    });
  }
  return <>{!shared&&<DirtyGuard dirty={dirty||state.busy} busy={state.busy}/>}<div className="pw-section-heading"><div><h2>{labels[type]}</h2>{!shared&&<p>{type==='questionnaire'?'שאלונים בתיק המטופל/ת ובפגישות':'כל הרשומות, כולל רשומות שמולאו באפליקציה ובפגישה'}</p>}</div><div className="pw-record-actions">{shared&&edit&&<button className="secondary" onClick={()=>setShowHistory(v=>!v)}>היסטוריה</button>}<button disabled={!write||state.busy||state.uncertain} onClick={()=>open()}><Plus size={18}/>{type==='questionnaire'?'שאלון חדש':'רשומה חדשה'}</button></div></div>
    {history.isPending?<Loading/>:history.isError?<ErrorBox error={history.error} retry={()=>void history.refetch()}/>:<HistoryContainer {...(type==='questionnaire'&&!shared?{}:{open:!edit||showHistory})} className={`pw-history ${shared&&edit&&!showHistory?'pw-history-collapsed':''}`}>{type==='questionnaire'&&!shared?<h3 className="pw-history-title">היסטוריה · {history.data.length} רשומות</h3>:<summary onClick={e=>{e.preventDefault();setShowHistory(v=>!v);}}>היסטוריה · {history.data.length} רשומות</summary>}<ul className="pw-record-list">{history.data.length===0?<li className="pw-list-empty">אין עדיין רשומות.</li>:history.data.map(row=><li key={String(row.id)}><button className={`pw-list-row ${type==='questionnaire'?'pw-questionnaire-row':'pw-diary-row'}`} aria-current={edit?.id===String(row.id)?'true':undefined} disabled={state.busy} onClick={()=>open(row)}><RecordSummary row={row} type={type}/><ChevronLeft size={18} aria-hidden="true"/></button></li>)}</ul></HistoryContainer>}
    {edit&&type==='questionnaire'&&showHistory&&<button className="secondary" onClick={()=>setShowHistory(false)}>חזרה לשאלון הפתוח</button>}
    {edit&&(type!=='questionnaire'||!showHistory)&&<RecordEditorFrame type={type} shared={shared} isNew={!edit.id} busy={state.busy} onClose={()=>{if(canReplace()){setEdit(null);state.reset();}}}><section className="pw-editor" ref={editorRoot}>{edit.id && history.data?.some(row=>String(row.id)===edit.id&&JSON.stringify(row)!==JSON.stringify(edit.original))&&<p className="notice">קיימים נתונים עדכניים בהיסטוריה. <button className="text-button" disabled={state.busy} onClick={()=>open(history.data?.find(row=>String(row.id)===edit.id))}>טעינת הרשומה מחדש</button></p>}<div className="pw-section-heading"><h3>{!editable?'לצפייה בלבד':state.saved?'נשמר בתיק':dirty?'שינויים שלא נשמרו':edit.id?'רשומה מההיסטוריה':'רשומה חדשה'}</h3><span>{edit.original?date(String(edit.original.created_at??edit.original.answered_date??'')):''}</span></div>
      {type==='questionnaire'&&!shared&&<label>שיוך לפגישה{edit.id?<p>{target?date(sessions.data?.find(s=>String(s.id)===target)?.session_date):'ללא פגישה'}</p>:<select value={target} disabled={state.busy} onChange={e=>{setTarget(e.target.value);state.changed();}}><option value="">ללא פגישה</option>{sessions.data?.map(s=><option value={String(s.id)} key={s.id}>{date(s.session_date)}</option>)}</select>}</label>}
      {type!=='questionnaire'&&<div className="reading-actions">{editing?<button className="secondary" disabled={state.busy} onClick={()=>{if(edit.original)open(edit.original);else if(canReplace()){setEdit(null);state.reset();}}}>ביטול עריכה</button>:editable&&<button className="secondary" onClick={()=>setEditing(true)}>עריכה</button>}</div>}
      {type!=='questionnaire'&&!editing?<DiaryReading item={edit.item} shared={shared}/>:<WorksheetEditor item={edit.item} shared presentation={shared} onChange={item=>{setEdit({...edit,item});state.changed();}} disabled={!editable||state.busy}/>}
      {type==='questionnaire'&&!shared&&<details className="pw-private-notes"><summary>הערות פרטיות למטפל/ת — אינן מוצגות בחלון השיתוף</summary><QuestionnaireNotes value={notes} disabled={!write||state.busy} onChange={value=>{setNotes(value);state.changed();}}/></details>}
      <SaveFeedback state={state} onInspect={()=>{setShowHistory(true);void history.refetch();}}/>
      {(type==='questionnaire'||editing)&&(type==='questionnaire'&&!shared&&notes!==undefined&&notes!==edit.original?.combined_notes?<ProcessingConsent><SaveButton state={state} valid={editable&&isFormComplete(edit.item)} save={save}/></ProcessingConsent>:<SaveButton state={state} valid={editable&&isFormComplete(edit.item)} save={save}/>)}
      {(type==='questionnaire'||editing)&&!isFormComplete(edit.item)&&<p className="pw-hint">יש להשלים את השדות הנדרשים לפני השמירה.</p>}
    </section></RecordEditorFrame>}</>;
}
function RecordEditorFrame({type,shared=false,isNew,busy,onClose,children}:{type:WorksheetType;shared?:boolean;isNew:boolean;busy:boolean;onClose:()=>void;children:ReactNode}) {
  return type==='questionnaire'&&!shared?<EditorDialog title={isNew?'שאלון חדש':'עריכת שאלון'} closeLabel={isNew?'ביטול':'חזרה לשאלונים'} busy={busy} onClose={onClose}>{children}</EditorDialog>:<><header className={`pw-diary-editor-heading ${shared?'pw-shared-editor-heading':''}`}><h2>{labels[type]}</h2><button type="button" className="secondary" disabled={busy} onClick={onClose}>חזרה לרשומות</button></header>{children}</>;
}
function RecordSummary({row,type}:{row:RecordRow;type:WorksheetType}) {
  const author=row.created_by==='patient'?'מולא על ידי המטופל/ת':'מולא על ידי המטפל/ת';
  if(type==='questionnaire') {
    const gad=questionnaireScore(Array.isArray(row.gad7_answers)?row.gad7_answers:[], 'gad');
    const phq=questionnaireScore(Array.isArray(row.phq9_answers)?row.phq9_answers:[], 'phq');
    const flagged=Array.isArray(row.phq9_answers)&&Number(row.phq9_answers[8])>0;
    return <><span className="pw-record-date"><strong>{date(typeof row.answered_date==='string'?row.answered_date:null)}</strong><small>תאריך המדידה</small></span><span className="pw-list-scores">{[['GAD-7',gad],['PHQ-9',phq]].map(([name,result])=>{const score=result as typeof gad;return <span key={String(name)} data-severity={score.total===null?'incomplete':score.total<5?'minimal':score.total<10?'mild':score.total<15?'moderate':'severe'}><b dir="ltr">{String(name)}</b><strong>{score.total??`${score.answered}/${score.count}`}</strong><small>{score.total===null?'תשובות · טרם הושלם':score.label}</small></span>;})}</span><span className="pw-record-meta">{row.session_id!=null?'משויך לפגישה':'ללא פגישה'}<small>{author}</small>{flagged&&<span className="pw-list-flag"><AlertCircle size={15} aria-hidden="true"/>לתשומת לב: שאלה 9</span>}</span></>;
  }
  const event=String(row[type==='diary_three'?'situation':'event']??'');
  const feelings=Array.isArray(row.feelings)?row.feelings.map(f=>typeof f?.name==='string'?f.name:'').filter(Boolean):[];
  return <><span className="pw-record-date"><strong>{date(String(row.created_at??''))}</strong><small>{author}</small></span><span className="pw-record-content"><span className="pw-record-preview">{event||'ללא תיאור אירוע'}</span>{feelings.length>0&&<small className="pw-record-meta">{feelings.join(' · ')}</small>}</span></>;
}
function SaveButton({state,valid,save}:{state:ReturnType<typeof useSaveState>;valid:boolean;save:()=>Promise<void>}) {
  return <div className="pw-save"><button disabled={!valid||state.busy||state.uncertain} aria-busy={state.busy} onClick={()=>void save()}>{state.busy?'שומר…':state.error?'ניסיון שמירה נוסף':'שמירה בתיק המטופל/ת'}</button></div>;
}
function QuestionnaireNotes({value,onChange,disabled}:{value:unknown;onChange:(v:unknown)=>void;disabled:boolean}) {
  const obj=value&&typeof value==='object'&&!Array.isArray(value)?value as Record<string,unknown>:{};
  return <>{(['gad7','phq9'] as const).map((key)=><div key={key}><h4>{key==='gad7'?'GAD-7':'PHQ-9'}</h4>{(key==='gad7'?mobile.gad7_questions:mobile.phq9_questions).map((text,i)=><label key={i}>{text}<textarea rows={2} disabled={disabled} value={Array.isArray(obj[key])?String(obj[key][i]??''):''} onChange={e=>onChange({...obj,[key]:Array.from({length:key==='gad7'?7:9},(_,n)=>n===i?e.target.value:Array.isArray(obj[key])?obj[key][n]??'':'')})}/></label>)}</div>)}<label>הערה על מידת ההפרעה<textarea rows={2} disabled={disabled} value={String(obj.interference??'')} onChange={e=>onChange({...obj,interference:e.target.value})}/></label></>;
}
function PatientSessions({patient}:{patient:string}) {
  const {session}=useAuth(),write=useWrite();
  const history=useQuery({queryKey:[session!.user.id,'record-sessions',patient],queryFn:()=>api.sessions(patient)});
  const [draft,setDraft]=useState<{id:string|null;day:string;type:string;notes:string;original?:string;record?:Record<string,unknown>}|null>(null),[baseline,setBaseline]=useState(''),[inspect,setInspect]=useState(false);
  const requested=new URLSearchParams(useLocation().search),requestedEntry=requested.get('entry'),requestedNew=requested.has('new');
  const consumed=useRef(false);
  const requestedOpen=useEffectEvent(()=>{if(consumed.current||!history.isSuccess)return;consumed.current=true;if(requestedNew)open({id:null,day:today(),type:'',notes:''});else if(requestedEntry){const s=history.data.find(r=>String(r.id)===requestedEntry);if(s)open({id:String(s.id),day:s.session_date.slice(0,10),type:s.type??'',notes:s.notes??'',original:s.notes??'',record:{...s}});}});
  useEffect(()=>{requestedOpen();},[history.isSuccess,requestedEntry,requestedNew]);
  const state=useSaveState(patient),dirty=!!draft&&JSON.stringify(draft)!==baseline;
  function open(d:NonNullable<typeof draft>) {if(state.busy||(dirty&&!window.confirm('יש שינויים שלא נשמרו. לוותר עליהם?')))return;setInspect(false);setDraft(d);setBaseline(JSON.stringify(d));state.reset();}
  async function save(){if(!draft)return;const snapshot=draft;await state.run(()=>savePatientSession(patient,snapshot.id,snapshot.day,snapshot.type,snapshot.notes,snapshot.original,snapshot.record),row=>{const next={...snapshot,id:String(row.id),original:String(row.notes??''),record:row};setDraft(next);setBaseline(JSON.stringify(next));});}
  return <><DirtyGuard dirty={dirty||state.busy} busy={state.busy}/><div className="pw-section-heading"><h2>פגישות וסיכומים</h2><button disabled={!write||state.busy||state.uncertain} onClick={()=>open({id:null,day:today(),type:'',notes:''})}><Plus size={18}/>פגישה חדשה</button></div>
    {history.isPending?<Loading/>:history.isError?<ErrorBox error={history.error} retry={()=>void history.refetch()}/>:<ul className="pw-session-list pw-record-list" aria-label="רשימת פגישות">{history.data.length===0&&<li className="pw-list-empty">אין עדיין פגישות.</li>}{history.data.map(s=><li key={s.id}><button className="pw-list-row pw-session-row" aria-current={draft?.id===String(s.id)?'true':undefined} disabled={state.busy} onClick={()=>open({id:String(s.id),day:s.session_date.slice(0,10),type:s.type??'',notes:s.notes??'',original:s.notes??'',record:{...s}})}><span className="pw-record-date"><strong>{date(s.session_date)}</strong><small>{s.type==='core_belief_challenge'?copy.coreBeliefChallenge:(mobile as Record<string,unknown>)[`session_type_${s.type}`] as string??'פגישה'}</small></span><span className={`pw-record-preview ${s.notes?'':'pw-record-meta'}`}>{s.notes||'עדיין אין סיכום לפגישה'}</span><span className="pw-record-action">פתיחת הפגישה</span><ChevronLeft size={18} aria-hidden="true"/></button></li>)}</ul>}

    {draft&&inspect&&<button className="secondary" onClick={()=>setInspect(false)}>חזרה לפגישה הפתוח</button>}
    {draft&&!inspect&&<EditorDialog title={draft.id?'עריכת פגישה':'פגישה חדשה'} closeLabel={draft.id?'חזרה לפגישות':'ביטול'} busy={state.busy} onClose={()=>{if(!state.busy&&(!dirty||window.confirm('יש שינויים שלא נשמרו. לוותר עליהם?'))){setDraft(null);state.reset();}}}><section className="pw-session-editor"><div className="form-row"><label>תאריך הפגישה<input type="date" required value={draft.day} disabled={!write||state.busy} onChange={e=>{setDraft({...draft,day:e.target.value});state.changed();}}/></label><label>סוג הפגישה<select disabled={!write||state.busy} value={draft.type} onChange={e=>{setDraft({...draft,type:e.target.value});state.changed();}}><option value="">{draft.id?'ללא סוג':'בחירת סוג פגישה'}</option><option value="core_belief_challenge">{copy.coreBeliefChallenge}</option>{Object.entries(mobile).filter(([key,v])=>key.startsWith('session_type_')&&!['session_type_label','session_type_none'].includes(key)&&typeof v==='string').map(([key,v])=><option key={key} value={key.replace('session_type_','')}>{v as string}</option>)}</select></label></div><label htmlFor="patient-session-summary">סיכום הפגישה<textarea id="patient-session-summary" aria-label="סיכום הפגישה" rows={8} maxLength={50000} value={draft.notes} disabled={!write||state.busy} onChange={e=>{setDraft({...draft,notes:e.target.value});state.changed();}}/></label><p className="pw-hint">שינוי הסיכום מחייב יצירה מחדש של הניתוח המובנה באפליקציה.</p><SaveFeedback state={state} onInspect={()=>{setInspect(true);void history.refetch();}}/><ProcessingConsent><SaveButton state={state} valid={write&&!!draft.day&& (!!draft.id||!!draft.type)} save={save}/></ProcessingConsent></section></EditorDialog>}
  </>;
}
