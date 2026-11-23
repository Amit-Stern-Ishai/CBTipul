import {useEffect,useRef,useState} from 'react';
import {useWrite} from '../ui/hooks';
import {DirtyGuard} from '../ui/shared';
import {ApiError,api} from '../data/api';
import {ConsentError} from '../data/consent';
import {conceptualization,conceptualSections,emptyConcept,validConcept,type ConceptDocument,type ConceptRecord} from '../data/conceptualization';
import './conceptualization.css';
import './reading.css';
export function ConceptualizationEditor({patient,shared=false,onDraftState}:{patient:string;shared?:boolean;onDraftState?:(state:{dirty:boolean;busy:boolean})=>void}) {
 const write=useWrite();
 const [editing,setEditing]=useState(false);
 const [record,setRecord]=useState<ConceptRecord|null>(null),[draft,setDraft]=useState<ConceptDocument>(emptyConcept),[backup,setBackup]=useState<ConceptDocument|null>(null),[busy,setBusy]=useState(false),[loaded,setLoaded]=useState(false),[message,setMessage]=useState(''),[error,setError]=useState(''),[conflict,setConflict]=useState(false);
 const root=useRef<HTMLElement>(null);
 useEffect(()=>{const frame=requestAnimationFrame(()=>{const target=root.current?.querySelector<HTMLElement>(editing?'textarea, .concept-section button':'h2');if(target?.matches('h2,h3'))target.setAttribute('tabindex','-1');target?.focus({preventScroll:true});});return()=>cancelAnimationFrame(frame);},[editing]);
 const alive=useRef(true);const dirty=loaded&&JSON.stringify(draft)!==JSON.stringify(record?.document??emptyConcept());
 useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
 useEffect(()=>{onDraftState?.({dirty,busy});return()=>onDraftState?.({dirty:false,busy:false});},[dirty,busy,onDraftState]);
 async function run(action:'load_draft'|'save'|'publish') {
  if(busy)return;setBusy(true);setError('');setMessage('');
  try {const result=await conceptualization(action,patient,record?.revision??null,draft);if(!alive.current)return;
   setRecord(result);setDraft(result.document??emptyConcept());setLoaded(true);setConflict(false);setEditing(false);
   setMessage(action==='save'?'ההמשגה נשמרה':action==='publish'?'ההמשגה נשלחה למטופל/ת':'');
  }catch(e){if(!alive.current)return;const code=e instanceof ApiError?e.code:'';setConflict(code==='revision_conflict');setError(code==='revision_conflict'?'ההמשגה השתנתה במכשיר אחר. השינויים שלכם נשארו כאן.':code==='access'?'אין הרשאה לפעולה זו.':action==='load_draft'?'לא הצלחנו לטעון את ההמשגה. אפשר לנסות שוב.':'לא ניתן לאשר שהפעולה הושלמה. השינויים נשארו כאן. אפשר לנסות שוב.');}
  finally{if(alive.current)setBusy(false);}
 }
 useEffect(()=>{void run('load_draft');/* scoped by parent account/patient key */},[]);
 function reload(){if(dirty){if(!confirm('לטעון את הגרסה העדכנית? תוכלו לחזור לשינויים שלכם מהעותק שנשמר כאן.'))return;setBackup(structuredClone(draft));}void run('load_draft');}
 return <section ref={root} className="concept-editor" aria-label="המשגה" aria-busy={busy}>
  {!shared&&<DirtyGuard dirty={dirty} busy={busy}/>}
  <header><h2>המשגה</h2>{loaded&&<span>{dirty?'שינויים שלא נשמרו':record?.revision?(record.published_revision===record.revision?'הגרסה השמורה נשלחה למטופל/ת':record.published_revision?'שינויים שמורים שטרם נשלחו':'טרם נשלחה למטופל/ת'):'אין עדיין המשגה'}</span>}</header>
  {error&&<div role="alert"><p>{error}</p><button className="secondary" disabled={busy} onClick={reload}>{conflict?'טעינת הגרסה העדכנית':'טעינה מחדש'}</button></div>}
  {backup&&<button className="secondary" disabled={busy} onClick={()=>{if(!dirty||confirm('להחליף את העריכה הנוכחית בעותק השינויים הקודם?')){setDraft(backup);setEditing(true);setBackup(null);setMessage('השינויים הוחזרו לעריכה. יש לשמור אותם.');}}}>חזרה לשינויים שלי</button>}
  {!loaded&&<p role="status">{busy?'טוענים המשגה…':'ההמשגה אינה זמינה כרגע.'}</p>}
  {loaded&&<>{!editing&&<>{write&&<div className="reading-actions"><button className="secondary" onClick={()=>setEditing(true)}>{record?.document?'עריכה':'יצירת המשגה'}</button></div>}{conceptualSections.filter(([key])=>draft[key].length).map(([key,title])=><section className="concept-reading" key={key}><h3>{title}</h3><ol>{draft[key].map((text,i)=><li key={i}><p dir="auto">{text}</p></li>)}</ol></section>)}{!conceptualSections.some(([key])=>draft[key].length)&&<p className="muted">אין עדיין משפטים בהמשגה.</p>}</>}{editing&&conceptualSections.map(([key,title],index)=><section className="concept-section" key={key}><h3><span>{index+1}</span>{title}</h3><ol>{draft[key].map((text,i)=><li key={i}><label className="ww-visually-hidden" htmlFor={`${key}-${i}`}>{title} {i+1}</label><textarea id={`${key}-${i}`} value={text} rows={2} disabled={busy||!write} onChange={e=>{setMessage('');setDraft(d=>({...d,[key]:d[key].map((v,j)=>j===i?e.target.value:v)}));}}/><button className="secondary" disabled={busy||!write} aria-label={`הסרת משפט ${i+1} — ${title}`} onClick={()=>setDraft(d=>({...d,[key]:d[key].filter((_,j)=>j!==i)}))}>הסרה</button></li>)}</ol>{!shared&&<ConceptSuggestions key={`${patient}:${key}`} patient={patient} section={key} draft={draft} disabled={busy||!write} onAdd={values=>{setMessage('');setDraft(d=>({...d,[key]:appendConceptSuggestions(d[key],values)}));}}/>}{!draft[key].length&&<p className="muted">אין עדיין משפטים</p>}<button className="secondary" disabled={busy||!write||draft[key].length>=30} onClick={()=>setDraft(d=>({...d,[key]:[...d[key],'']}))}>הוספת משפט</button></section>)}
  {editing&&!validConcept(draft)&&<p role="status">יש למלא כל משפט (עד 1,500 תווים), או להסיר משפט ריק.</p>}
  <footer>{editing&&<><button className="secondary" disabled={busy} onClick={()=>{if(!dirty||confirm('יש שינויים שלא נשמרו. לוותר עליהם?')){setDraft(record?.document??emptyConcept());setEditing(false);setError('');setConflict(false);}}}>ביטול עריכה</button><button disabled={busy||!write||!validConcept(draft)||(!dirty&&!!record?.revision)} onClick={()=>void run('save')}>{busy?'ממתינים…':'שמירה'}</button></>}<button className="secondary" disabled={busy||!write||dirty||!record?.revision||conflict} onClick={()=>void run('publish')}>שליחה למטופל/ת</button><button className="secondary" disabled={busy} onClick={reload}>רענון</button></footer>
  {dirty&&<p>יש לשמור את השינויים לפני השליחה.</p>}
  {record?.published_at&&<p>עותק נשלח למטופל/ת · {new Date(record.published_at).toLocaleString('he-IL')}</p>}
  </>}{message&&<p role="status">{message}</p>}
 </section>;
}

export function appendConceptSuggestions(existing:string[],selected:string[]):string[]{
 const result=[...existing];for(const text of selected){if(result.length<30&&!result.some(v=>v.trim()===text.trim()))result.push(text);}return result;
}
function ConceptSuggestions({patient,section,draft,disabled,onAdd}:{patient:string;section:keyof ConceptDocument;draft:ConceptDocument;disabled:boolean;onAdd:(v:string[])=>void}){
 const alive=useRef(true),pending=useRef(false);const [loading,setLoading]=useState(false),[values,setValues]=useState<string[]|null>(null),[picked,setPicked]=useState<string[]>([]),[error,setError]=useState('');
 useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
 async function generate(){if(disabled||pending.current)return;pending.current=true;setLoading(true);setError('');setValues(null);setPicked([]);const snapshot=structuredClone(draft);
 try{const result=await api.conceptualizationSuggestions(patient,section,snapshot,()=>alive.current);if(alive.current)setValues(result.filter(v=>!snapshot[section].some(s=>s.trim()===v.trim())));}
 catch(e){if(alive.current)setError(conceptSuggestionError(e));}finally{pending.current=false;if(alive.current)setLoading(false);}}
 return <div className="concept-suggestions"><button className="concept-ai-option" disabled={disabled||loading} onClick={()=>void generate()}>{loading?'מכינים הצעות…':error?'ניסיון נוסף — הצעות AI':'הצעות AI'}</button>
 {error&&<p role="alert">{error}</p>}{values&&<div aria-live="polite">{values.length===0?<p>אין מספיק מידע להצעות</p>:<><p className="muted">הצעות לבדיקה — בחרו מה להוסיף</p>{values.map(text=><label className="concept-suggestion" key={text}><input type="checkbox" checked={picked.includes(text)} disabled={disabled} onChange={e=>setPicked(p=>e.target.checked?[...p,text]:p.filter(v=>v!==text))}/><span>{text}</span></label>)}<button className="secondary" disabled={disabled||!picked.length||draft[section].length+picked.filter(v=>!draft[section].includes(v)).length>30} onClick={()=>{onAdd(picked);setValues(null);setPicked([]);}}>הוספת הנבחרות</button></>}</div>}</div>;
}
export function conceptSuggestionError(error:unknown){const code=error instanceof ApiError||error instanceof ConsentError?error.code:'';if(code==='consent_lookup')return 'לא הצלחנו לבדוק את אישור השימוש ב־AI. אפשר לנסות שוב ולהמשיך לערוך ידנית.';if(code==='consent_unavailable')return 'בדיקת אישור השימוש ב־AI אינה זמינה כרגע. אפשר להמשיך לערוך ידנית.';return code==='access'?'אין הרשאה להצעות עבור המטופל/ת. חזרו לתיק ונסו שוב.':code==='too_large'?'המידע ארוך מדי לעיבוד. קצרו את הטיוטה ונסו שוב.':code==='quota'?'מכסת ה־AI נוצלה. אפשר להמשיך לערוך ידנית ולנסות לאחר חידוש המכסה.':code==='rate_limit'?'נשלחו בקשות רבות. המתינו מעט ונסו שוב.':code.startsWith('consent')?'יש לאשר שימוש ב־AI לפני קבלת הצעות. נסו שוב.':'לא הצלחנו לקבל הצעות. הטיוטה לא השתנתה. נסו שוב.';}
