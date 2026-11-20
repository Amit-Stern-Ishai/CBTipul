import {type ReactNode} from 'react';
import {DiaryFlow} from './DiaryFlow';
import {thinkingErrors,type Worksheet} from './model';
import './reading.css';
import mobile from '../mobile-he.json';
type Row=Record<string,unknown>;
const list=(v:unknown):unknown[]=>Array.isArray(v)?v:[];
const text=(v:unknown)=>typeof v==='string'?v:'';
function Rating({label,value}:{label:string;value:unknown}){return typeof value==='number'?<span className="reading-rating">{label} <bdi>{value}%</bdi></span>:null;}
function Part({title,children}:{title:string;children:ReactNode}){return <section className="ww-diary-section reading-section"><h2 tabIndex={-1}>{title}</h2>{children}</section>;}
export function DiaryReading({item,shared}:{item:Worksheet;shared:boolean}){
 const d=item.data,third=item.type==='diary_three';
 const thoughts=(key:string)=>list(d[key]).map((v,i)=>{const row=typeof v==='object'&&v?v as Row:{};const value=typeof v==='string'?v:text(row.text);return value.trim()?<li key={i}><p dir="auto">{value}</p>{third&&<div className="reading-ratings">{key==='automatic_thoughts'?<><Rating label="אמונה לפני" value={row.beliefBefore}/><Rating label="אמונה אחרי" value={row.beliefAfter}/></>:<Rating label="אמונה" value={row.belief}/>}</div>}</li>:null;});
 return <div className="diary-reading"><DiaryFlow presentation={shared} reading initialOverview={!shared}>
  <Part title={third?'המצב':'האירוע'}><p dir="auto">{text(d[third?'situation':'event'])}</p></Part>
  <Part title="מחשבות אוטומטיות"><ul>{thoughts('automatic_thoughts')}</ul></Part>
  <Part title="רגשות"><ul>{list(d.feelings).map((v,i)=>{const f=v as Row;return <li key={i}><p>{text(f.name)}</p><div className="reading-ratings">{third?<><Rating label="לפני" value={f.intensityBefore}/><Rating label="אחרי" value={f.intensityAfter}/></>:<Rating label="עוצמה" value={f.intensity}/>}</div></li>;})}</ul></Part>
  {item.type==='diary_one'?<Part title="התנהגות ותחושות גוף"><p dir="auto">{text(d.behaviour)}</p>{text(d.physical_symptoms).trim()&&<><h3>תחושות גוף</h3><p dir="auto">{text(d.physical_symptoms)}</p></>}</Part>:<>
  <Part title="טעויות חשיבה">{list(d.thinking_errors).length?<ul>{list(d.thinking_errors).map((v,i)=><li key={i}>{mobile[thinkingErrors.find(([key])=>key===v)?.[1] as keyof typeof mobile]??text(v)}</li>)}</ul>:<p>לא זוהתה טעות חשיבה</p>}</Part>
  <Part title="מחשבות חלופיות"><ul>{thoughts('alternative_thoughts')}</ul></Part></>}
 </DiaryFlow></div>;
}
