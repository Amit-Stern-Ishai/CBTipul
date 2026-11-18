import type { RecordRow } from '../data/patient-workspace';
import { questionnaireScore } from './scores';
export type TimelineKind='session'|'questionnaire'|'diary';
export type TimelineEntry={key:string;id:string;section:string;kind:TimelineKind;day:string|null;title:string;score?:ReturnType<typeof questionnaireScore>;flagged?:boolean;hasNotes?:boolean;recordedAt?:number};
export function dayKey(value:unknown):string|null {
 if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}/.test(value))return null;
 const key=value.slice(0,10), d=new Date(key+'T12:00:00');
 return Number.isFinite(d.getTime())&&localDay(d)===key?key:null;
}
export function localDay(d:Date){return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;}
export function weekStart(day:string){const d=new Date(day+'T12:00:00');d.setDate(d.getDate()-d.getDay());return localDay(d);}
export function monthDays(month:Date){const start=new Date(month.getFullYear(),month.getMonth(),1,12);start.setDate(start.getDate()-start.getDay());const end=new Date(month.getFullYear(),month.getMonth()+1,0,12);end.setDate(end.getDate()+6-end.getDay());const days:string[]=[];for(const d=new Date(start);d<=end;d.setDate(d.getDate()+1))days.push(localDay(d));return days;}
export function severity(total:number|null){return total===null?'incomplete':total<5?'minimal':total<10?'mild':total<15?'moderate':'severe';}
export function timelineEntries(sessions:Record<string,unknown>[],questionnaires:RecordRow[],diaries:RecordRow[][]):TimelineEntry[]{
 const entries:TimelineEntry[]=sessions.map(s=>({key:`session:${s.id}`,id:String(s.id),section:'sessions',kind:'session',day:dayKey(s.session_date),title:'פגישה',hasNotes:typeof s.notes==='string'&&!!s.notes.trim()}));
 questionnaires.forEach(q=>{(['gad','phq'] as const).forEach(kind=>{const answers=q[kind==='gad'?'gad7_answers':'phq9_answers'];entries.push({key:`${kind}:${q.id}`,id:String(q.id),section:'questionnaire',kind:'questionnaire',day:dayKey(q.answered_date),title:kind==='gad'?'GAD-7':'PHQ-9',recordedAt:typeof q.created_at==='string'?Date.parse(q.created_at):undefined,score:questionnaireScore(Array.isArray(answers)?answers:[],kind),flagged:kind==='phq'&&Array.isArray(answers)&&Number(answers[8])>0});});});
 diaries.forEach((rows,i)=>rows.forEach(r=>entries.push({key:`diary${i}:${r.id}`,id:String(r.id),section:['diary_one','diary_two','diary_three'][i],kind:'diary',day:dayKey(r.created_at),title:`יומן מחשבות ${i+1}`})));
 return entries.sort((a,b)=>(b.day??'').localeCompare(a.day??'')||a.key.localeCompare(b.key));
}

// Do not infer measurement recency from opaque IDs when timestamps are unavailable.
export function latestScore(entries:TimelineEntry[],title:string){
 const candidates=entries.filter(e=>e.title===title&&e.day).sort((a,b)=>b.day!.localeCompare(a.day!));
 if(!candidates.length)return undefined;
 const sameDay=candidates.filter(e=>e.day===candidates[0].day);
 if(sameDay.length===1)return sameDay[0];
 if(sameDay.some(e=>!Number.isFinite(e.recordedAt)))return undefined;
 sameDay.sort((a,b)=>b.recordedAt!-a.recordedAt!);
 return sameDay[0].recordedAt===sameDay[1].recordedAt?undefined:sameDay[0];
}
