import {useEffect,useRef,useState} from 'react';
import {useQueries} from '@tanstack/react-query';
import {Link} from 'react-router-dom';
import {ArrowRight,ArrowLeft,ChevronDown,Plus,BookOpen,ClipboardList,Users,AlertCircle} from 'lucide-react';
import {useAuth} from '../auth/Auth';
import {useWrite} from '../ui/hooks';
import {api} from '../data/api';
import {recordHistory,type RecordRow} from '../data/patient-workspace';
import {ErrorBox,Loading,date} from '../ui/shared';
import {latestScore,localDay,weekStart,monthDays,severity,timelineEntries,type TimelineEntry,type TimelineKind} from './patient-timeline';
import './patient-timeline.css';
const categories=[['session','פגישות',Users],['questionnaire','שאלונים',ClipboardList],['diary','יומנים',BookOpen]] as const;
const forms=[['sessions','פגישה חדשה'],['questionnaire','שאלון חדש'],['diary_one','יומן מחשבות 1'],['diary_two','יומן מחשבות 2'],['diary_three','יומן מחשבות 3']];
export function PatientTimeline({patient,name}:{patient:string;name:string}){
 const identityRef=useRef<HTMLElement>(null),rootRef=useRef<HTMLElement>(null);
 useEffect(()=>{const el=identityRef.current;if(!el)return;const observer=new ResizeObserver(()=>rootRef.current?.style.setProperty('--pt-identity-height',`${el.offsetHeight}px`));observer.observe(el);return()=>observer.disconnect();},[]);
 const {session}=useAuth(),write=useWrite(),account=session!.user.id;
 const [view,setView]=useState<'calendar'|'list'>('list'),[filter,setFilter]=useState<TimelineKind|'all'>('all');
 const [month,setMonth]=useState(()=>new Date(new Date().getFullYear(),new Date().getMonth(),1,12));
 const queries=useQueries({queries:[
  {queryKey:[account,'record-sessions',patient],queryFn:()=>api.sessions(patient).then(rows=>rows.map(r=>({...r,id:String(r.id),patient_id:String(r.patient_id)})))},
  ...(['questionnaire','diary_one','diary_two','diary_three'] as const).map(type=>({queryKey:[account,'private-records',patient,type],queryFn:()=>recordHistory(patient,type,false)}))
 ]});
 const entries=timelineEntries(queries[0].data??[],(queries[1].data??[]) as RecordRow[],queries.slice(2).map(q=>(q.data??[]) as RecordRow[]));
 const visible=entries.filter(e=>filter==='all'||e.kind===filter), days=monthDays(month), today=localDay(new Date());
 const dated=visible.filter(e=>e.day),undated=visible.filter(e=>!e.day);
 const weeks=[...new Set(dated.map(e=>weekStart(e.day!)))].sort().reverse();
 const headingScores=[latestScore(entries,'GAD-7'),latestScore(entries,'PHQ-9')].filter((e):e is TimelineEntry=>!!e&&e.score?.total!==null);
 const monthLabel=new Intl.DateTimeFormat('he',{month:'long',year:'numeric'}).format(month);
 const path=`/patients/${patient}`;
 const open=(section:string,id?:string)=>`${path}/${section}?${id?`entry=${encodeURIComponent(id)}`:'new=1'}`;
 function Entry({entry,compact=false}:{entry:TimelineEntry;compact?:boolean}){
  const Icon=categories.find(([key])=>key===entry.kind)![2];
  return <Link className={`pt-entry ${compact?'pt-entry-compact':''}`} data-kind={entry.kind} to={open(entry.section,entry.id)} aria-label={[entry.title,entry.day?date(entry.day):'ללא תאריך',entry.score?(entry.score.total===null?`${entry.score.answered}/${entry.score.count} · טרם הושלם`:`${entry.score.total} · ${entry.score.label}`):'',entry.kind==='session'?(entry.hasNotes?'סיכום':'ללא סיכום'):'',entry.flagged?'לתשומת לב: שאלה 9':''].filter(Boolean).join(' · ')}>
   <span className="pt-entry-icon"><Icon size={17} aria-hidden="true"/></span>
   <span className="pt-entry-copy"><strong dir={entry.score?'ltr':undefined}>{entry.title}</strong>
   {entry.score&&<span className="pt-score" data-severity={severity(entry.score.total)}>{entry.score.total===null?`${entry.score.answered}/${entry.score.count} · טרם הושלם`:`${entry.score.total} · ${(entry.score.label??'').replace(/^(חרדה|דיכאון) /,'')}`}</span>}
   {!compact&&<small>{entry.day?date(entry.day):'ללא תאריך מדידה'}{entry.kind==='session'&&` · ${entry.hasNotes?'סיכום':'ללא סיכום'}`}</small>}
   </span>{entry.flagged&&<AlertCircle className="pt-flag-icon" size={16} aria-label="לתשומת לב: שאלה 9"/>}
  </Link>;
 }
 return <section ref={rootRef} className="pt" aria-label="תיק המטופל/ת">
  <header ref={identityRef} className="pt-identity"><div className="pt-patient"><div className="pt-patient-title"><Link className="pt-back" to="/" aria-label="כל המטופלים"><ArrowRight size={20}/></Link><h1>{name}</h1><div className="pt-head-scores">{headingScores.map(e=><span key={e.key} className="pt-score" data-severity={severity(e.score!.total)}>{e.score!.label}</span>)}{headingScores.some(e=>e.flagged)&&<span className="pt-score" data-severity="severe">לתשומת לב: שאלה 9</span>}</div></div></div>
   <div className="pt-primary-actions">{write&&<Link className="button pt-start" to={`/shared/${patient}/questionnaire`} state={{patient,account,name}}><Plus size={17}/>התחלת פגישה כעת</Link>}<div className="pt-view" role="group" aria-label="תצוגת התיק"><button aria-pressed={view==='calendar'} onClick={()=>setView('calendar')}>לוח שנה</button><button aria-pressed={view==='list'} onClick={()=>{setFilter('all');setView('list');}}>רשימה</button></div></div>
  </header>
  {view==='calendar'&&<div className="pt-toolbar"><div className="pt-period">{view==='calendar'&&<><button className="secondary" onClick={()=>setMonth(new Date(new Date().getFullYear(),new Date().getMonth(),1,12))}>היום</button><button className="secondary" aria-label="החודש הקודם" onClick={()=>setMonth(new Date(month.getFullYear(),month.getMonth()-1,1,12))}><ArrowRight size={16}/></button><button className="secondary" aria-label="החודש הבא" onClick={()=>setMonth(new Date(month.getFullYear(),month.getMonth()+1,1,12))}><ArrowLeft size={16}/></button></>}<h2>{view==='calendar'?monthLabel:'התיעוד בתיק'}</h2></div>
   <div className="pt-filters" role="group" aria-label="סינון לפי סוג">{(['all',...categories.map(c=>c[0])] as const).map(key=><button key={key} aria-pressed={filter===key} onClick={()=>setFilter(key)}>{key!=='all'&&<span className="pt-filter-icon" data-kind={key}>{key==='session'?<Users size={14}/>:key==='questionnaire'?<ClipboardList size={14}/>:<BookOpen size={14}/>}</span>}{key==='all'?'הכל':categories.find(c=>c[0]===key)![1]}</button>)}</div>
   {write&&<details className="pt-add"><summary><Plus size={16}/>הוספה<ChevronDown size={14}/></summary><div>{forms.map(([key,title])=><Link key={key} to={open(key)}>{title}</Link>)}</div></details>}
  </div>}
  {queries.filter(q=>q.isError).map((q,i)=><ErrorBox key={i} error={q.error} retry={()=>void q.refetch()}/>)}
  {queries.some(q=>q.isPending)?<Loading/>:<>
  {view==='calendar'?<div className="pt-calendar" aria-label={monthLabel}><div className="pt-weekdays">{['א׳','ב׳','ג׳','ד׳','ה׳','ו׳','ש׳'].map(d=><span key={d}>{d}</span>)}</div><div className="pt-days">{days.map(day=><section key={day} className={`pt-day ${day.slice(0,7)!==localDay(month).slice(0,7)?'pt-outside':''}`} aria-label={date(day)}><time dateTime={day} aria-current={day===today?'date':undefined}>{Number(day.slice(-2))}</time>{dated.filter(e=>e.day===day).map(entry=><Entry key={entry.key} entry={entry} compact/>)}</section>)}</div></div>:
  <div className="pt-weeks">{write&&<details className="pt-add pt-mobile-add"><summary><Plus size={16}/>הוספה</summary><div>{forms.map(([key,label])=><Link key={key} to={open(key)}>{label}</Link>)}</div></details>}<div className="pt-column-headings">{categories.map(([kind,title])=><div key={kind}><h3>{title}</h3>{write&&(kind==='diary'?<details className="pt-add pt-diary-add"><summary>כתיבה ביומן <Plus size={16}/></summary><div>{forms.slice(2).map(([key,label])=><Link key={key} to={open(key)}>{label}</Link>)}</div></details>:<Link to={open(kind==='session'?'sessions':'questionnaire')}>{kind==='session'?'פגישה חדשה':'מילוי שאלון'}<Plus size={16}/></Link>)}</div>)}</div>{weeks.map(week=><section className={`pt-week ${week===weekStart(today)?'pt-week-now':''}`} key={week}><h3>{date(week)} – {date(localDay(new Date(new Date(week+'T12:00:00').getTime()+6*86400000)))}</h3><div className="pt-week-columns">{categories.map(([kind,title])=><div key={kind} className="pt-week-column"><h4>{title}</h4>{dated.filter(e=>weekStart(e.day!)===week&&e.kind===kind).map(entry=><Entry key={entry.key} entry={entry}/>)}</div>)}</div></section>)}{!weeks.length&&<p className="pt-empty">אין עדיין רשומות בתצוגה זו.</p>}</div>}
  {undated.length>0&&<section className="pt-undated"><h3>ללא תאריך</h3>{undated.map(entry=><Entry key={entry.key} entry={entry}/>)}</section>}
  </>}
 </section>;
}
