import {useEffect,useRef,useState} from 'react';
import {useWrite} from '../ui/hooks';
import {DirtyGuard} from '../ui/shared';
import {ApiError} from '../data/api';
import {coreBeliefRequest} from '../data/coreBeliefWorksheetApi';
import {emptyCoreBeliefWorksheet,encodeCoreBeliefWorksheet,type CoreBeliefWorksheet,type CoreBeliefWorksheetRecord,type CoreBeliefStatement} from '../data/coreBeliefWorksheet';
import {Rating as DiaryRating,FeelingPicker} from './DiaryWorksheet';
import {DiaryFlow} from './DiaryFlow';
import './core-belief.css';
import './conceptualization.css';
import './reading.css';
export function CoreBeliefEditor({patient,shared=false,onDraftState}:{patient:string;shared?:boolean;onDraftState?:(state:{dirty:boolean;busy:boolean})=>void}) {
 const write=useWrite();
 const [editing,setEditing]=useState(false);
 const [record,setRecord]=useState<CoreBeliefWorksheetRecord|null>(null),[draft,setDraft]=useState<CoreBeliefWorksheet>(emptyCoreBeliefWorksheet),[backup,setBackup]=useState<CoreBeliefWorksheet|null>(null),[busy,setBusy]=useState(false),[loaded,setLoaded]=useState(false),[message,setMessage]=useState(''),[error,setError]=useState(''),[conflict,setConflict]=useState(false);
 const root=useRef<HTMLElement>(null);
 useEffect(()=>{const frame=requestAnimationFrame(()=>{const target=root.current?.querySelector<HTMLElement>(editing?'.diary-flow-panel:not([hidden]) textarea, .ww-diary-grid > .core-belief-section textarea':'h2');if(target?.matches('h2,h3'))target.setAttribute('tabindex','-1');target?.focus({preventScroll:true});});return()=>cancelAnimationFrame(frame);},[editing]);
 const alive=useRef(true),pending=useRef(false);const dirty=loaded&&JSON.stringify(draft)!==JSON.stringify(record?.document??emptyCoreBeliefWorksheet());
 useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
 useEffect(()=>{onDraftState?.({dirty,busy});return()=>onDraftState?.({dirty:false,busy:false});},[dirty,busy,onDraftState]);
 async function run(action:'load_draft'|'save'|'publish') {
  if(pending.current)return;pending.current=true;setBusy(true);setError('');setMessage('');
  try {const result=await coreBeliefRequest(action,patient,record?.revision??null,draft);if(!alive.current)return;
   setRecord(result);setDraft(result.document??emptyCoreBeliefWorksheet());setLoaded(true);setConflict(false);setEditing(action==='load_draft'&&result.document===null&&write);
   setMessage(action==='save'?'המסמך נשמר':action==='publish'?'המסמך נשלח למטופל/ת':'');
  }catch(e){if(!alive.current)return;const code=e instanceof ApiError?e.code:'';setConflict(code==='revision_conflict');setError(code==='revision_conflict'?'המסמך השתנה במכשיר אחר. השינויים שלכם נשארו כאן.':code==='access'?'אין הרשאה לפעולה זו.':'לא ניתן לאשר שהפעולה הושלמה. השינויים נשארו כאן. אפשר לנסות שוב.');}
  finally{pending.current=false;if(alive.current)setBusy(false);}
 }
 useEffect(()=>{void run('load_draft');/* scoped by parent account/patient key */},[]);
 function reload(){if(dirty){if(!confirm('לטעון את הגרסה העדכנית? תוכלו לחזור לשינויים שלכם מהעותק שנשמר כאן.'))return;setBackup(structuredClone(draft));}void run('load_draft');}
 return <section ref={root} className="concept-editor core-belief-editor" aria-label="ערעור אמונת יסוד" aria-busy={busy}>
  {!shared&&<DirtyGuard dirty={dirty} busy={busy}/>}
  <header><h2>ערעור אמונת יסוד</h2>{loaded&&<span>{dirty?'שינויים שלא נשמרו':record?.revision?(record.publishedRevision===record.revision?'הגרסה השמורה נשלחה למטופל/ת':record.publishedRevision?'שינויים שמורים שטרם נשלחו':'טרם נשלחה למטופל/ת'):'אין עדיין ערעור אמונת יסוד'}</span>}</header>
  {error&&<div role="alert"><p>{error}</p><button className="secondary" disabled={busy} onClick={reload}>{conflict?'טעינת הגרסה העדכנית':'טעינה מחדש'}</button></div>}
  {backup&&<button className="secondary" disabled={busy} onClick={()=>{if(!dirty||confirm('להחליף את העריכה הנוכחית בעותק השינויים הקודם?')){setDraft(backup);setEditing(true);setBackup(null);setMessage('השינויים הוחזרו לעריכה. יש לשמור אותם.');}}}>חזרה לשינויים שלי</button>}
  {!loaded&&<p role="status">{busy?'טוענים ערעור אמונת יסוד…':'המסמך אינו זמין כרגע.'}</p>}
  {loaded&&<>{!editing&&write&&<div className="reading-actions"><button className="secondary" onClick={()=>setEditing(true)}>עריכה</button></div>}
  <fieldset disabled={busy||!write&&editing} className="core-belief-fields"><DiaryFlow staged={false} presentation={shared} reading={!editing} initialOverview={!shared}>
    <CoreSection title="אמונת היסוד הישנה"><BeliefFields value={draft.oldBelief} disabled={busy||!write} editing={editing} change={v=>setDraft(d=>({...d,oldBelief:v}))}/></CoreSection>
    <CoreSection title="אמונת יסוד מאוזנת"><BeliefFields value={draft.balancedBelief} disabled={busy||!write} editing={editing} change={v=>setDraft(d=>({...d,balancedBelief:v}))}/></CoreSection>
    {([['oldEvidence','הוכחות בעד האמונה הישנה'],['alternativeInterpretations','דרכים חלופיות להסתכל על הראיות'],['balancedEvidence','הוכחות בעד האמונה המאוזנת'],['experiments','התנהגות חדשה / ניסויים']] as const).map(([key,title])=><CoreSection key={key} title={title}><TextValue hideLabel title={title} value={draft[key]} editing={editing} change={v=>setDraft(d=>({...d,[key]:v}))}/></CoreSection>)}
    <CoreSection title="דירוג מסכם"><Rating title="האמונה הישנה" value={draft.finalOldRating} editing={editing} change={v=>setDraft(d=>({...d,finalOldRating:v}))}/><Rating title="האמונה המאוזנת" value={draft.finalBalancedRating} editing={editing} change={v=>setDraft(d=>({...d,finalBalancedRating:v}))}/></CoreSection>
  </DiaryFlow></fieldset>
  <footer>{editing&&<><button className="secondary" disabled={busy} onClick={()=>{if(!dirty||confirm('יש שינויים שלא נשמרו. לוותר עליהם?')){setDraft(record?.document??emptyCoreBeliefWorksheet());setEditing(false);setError('');setConflict(false);}}}>ביטול עריכה</button><button disabled={busy||!write||!validWorksheet(draft)||(!dirty&&!!record?.revision)} onClick={()=>void run('save')}>{busy?'ממתינים…':'שמירה'}</button></>}<button className="secondary" disabled={busy||!write||dirty||!record?.revision||conflict} onClick={()=>void run('publish')}>שליחת עותק למטופל/ת</button><button className="secondary" disabled={busy} onClick={reload}>רענון</button></footer>
  {dirty&&<p>יש לשמור את השינויים לפני השליחה.</p>}
  {record?.publishedAt&&<p>עותק נשלח למטופל/ת · {new Date(record.publishedAt).toLocaleString('he-IL')}</p>}
  </>}{message&&<p role="status">{message}</p>}
 </section>;
}

function validWorksheet(value:CoreBeliefWorksheet){try{encodeCoreBeliefWorksheet(value);return true;}catch{return false;}}
function CoreSection({title,children}:{title:string;children:React.ReactNode}){return <section className="ww-diary-section core-belief-section"><h2>{title}</h2>{children}</section>;}
function TextValue({title,value,editing,change,hideLabel=false}:{title:string;value:string;editing:boolean;change:(v:string)=>void;hideLabel?:boolean}){return editing?<label>{!hideLabel&&title}<textarea aria-label={title} rows={3} maxLength={10000} value={value} onChange={e=>change(e.target.value)}/></label>:<>{title==='רגשות'&&<strong>רגשות</strong>}{value?<p className="core-belief-text" dir="auto">{value}</p>:<p className="muted">לא מולא</p>}</>;}
function Rating({title,value,editing,change}:{title:string;value:number|null;editing:boolean;change:(v:number|null)=>void}){return editing?<DiaryRating title={title} defaultValue={80} value={value} disabled={false} onChange={change}/>:<div className="core-belief-rating">{title}<strong dir="ltr">{value===null?'—':`${value}%`}</strong></div>;}
function Feelings({value,disabled,change}:{value:string;disabled:boolean;change:(v:string)=>void}) {
 const names=value.split('\n').filter(Boolean);
 return <div className="core-feelings"><strong>רגשות</strong>{names.map((name,index)=><div className="core-feeling" key={index}><span dir="auto">{name}</span><button type="button" className="secondary" aria-label={`הסרת רגש: ${name}`} disabled={disabled} onClick={()=>change(names.filter((_,i)=>i!==index).join('\n'))}>×</button></div>)}<FeelingPicker values={names.map(name=>({name}))} third={false} disabled={disabled} onChange={rows=>change(rows.map(row=>String(row.name)).join('\n'))}/></div>;
}
function BeliefFields({value,editing,disabled,change}:{value:CoreBeliefStatement;editing:boolean;disabled:boolean;change:(v:CoreBeliefStatement)=>void}){return <><TextValue title="האמונה" value={value.text} editing={editing} change={text=>change({...value,text})}/><div className="core-belief-ratings">{([['now','עכשיו'],['most','הכי הרבה'],['least','הכי מעט']] as const).map(([key,title])=><Rating key={key} title={title} value={value[key]} editing={editing} change={v=>change({...value,[key]:v})}/>)}</div>{editing?<Feelings disabled={disabled} value={value.feelings} change={feelings=>change({...value,feelings})}/>:<TextValue title="רגשות" value={value.feelings} editing={false} change={()=>{}}/>}</>;}
