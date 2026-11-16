import { Children, Fragment, isValidElement, useId, useRef, useState, useEffect, type CSSProperties, type ReactNode } from 'react';
import { ArrowLeft, ArrowRight, List, Rows3, Minus, Plus, Maximize, Minimize } from 'lucide-react';

function flatten(children: ReactNode): ReactNode[] {
  return Children.toArray(children).flatMap(child => isValidElement<{children?:ReactNode}>(child) && child.type === Fragment ? flatten(child.props.children) : [child]);
}
/** Presentation state only: clinical values stay controlled by the parent worksheet. */
export function DiaryFlow({children,presentation=false}:{children:ReactNode;presentation?:boolean}) {
  const [step,setStep]=useState(0), [all,setAll]=useState(false);
  const [textSize,setTextSize]=useState(4.6), [fullscreen,setFullscreen]=useState(false), [screenError,setScreenError]=useState('');
  useEffect(()=>{
    const update=()=>setFullscreen(!!document.fullscreenElement);
    document.addEventListener('fullscreenchange',update);
    return()=>document.removeEventListener('fullscreenchange',update);
  },[]);
  async function toggleFullscreen(){
    setScreenError('');
    try{if(document.fullscreenElement)await document.exitFullscreen();else await root.current?.closest<HTMLElement>('.pw-shared')?.requestFullscreen();}
    catch{setScreenError('מסך מלא אינו זמין בדפדפן זה. אפשר להמשיך לשתף את החלון.');}
  }
  const root=useRef<HTMLDivElement>(null), id=useId();
  const parts=flatten(children).filter(child=>isValidElement<{className?:string}>(child) && child.props.className!=='ww-diary-stage');
  const titles=parts.map(part=>isValidElement<{title?:string}>(part)?part.props.title??'':'' );
  function move(next:number) {
    setStep(next);
    requestAnimationFrame(()=>{
      const heading=root.current?.querySelector<HTMLElement>('.ww-diary-section h2');
      heading?.setAttribute('tabindex','-1');heading?.focus({preventScroll:true});
      if(presentation)root.current?.querySelector('.ww-diary-grid')?.scrollTo({top:0});else root.current?.scrollIntoView({block:'start',behavior:'instant'});
    });
  }
  return <div ref={root} className={`diary-flow ${all?'diary-flow-all':'diary-flow-focus'} ${presentation?'diary-presentation':''}`} style={presentation?{'--presentation-type':`${textSize}vw`} as CSSProperties:undefined}>
    <header className="diary-flow-toolbar">
      <div className="diary-flow-mode" role="group" aria-label="תצוגת היומן">
        <button type="button" aria-pressed={!all} onClick={()=>setAll(false)}><Rows3 size={18} aria-hidden="true"/>חלק אחד</button>
        <button type="button" aria-pressed={all} onClick={()=>setAll(true)}><List size={18} aria-hidden="true"/>היומן המלא</button>
      </div>
      <p>{all?'כל חלקי היומן לפניכם. אפשר לחזור לעבודה בחלק אחד בכל רגע.':'מתמקדים בחלק אחד בכל פעם. אפשר לחזור ולשנות כל תשובה.'}</p>
      {!all && <div className="diary-flow-location"><label htmlFor={id}>מעבר לחלק</label><select id={id} value={step} onChange={e=>move(Number(e.target.value))}>{titles.map((title,i)=><option key={i} value={i}>{i+1}. {title}</option>)}</select><span role="status" aria-live="polite">חלק {step+1} מתוך {parts.length}</span></div>}
      {presentation && <div className="diary-presentation-controls" role="group" aria-label="התאמה לצפייה בשיתוף מסך">
        <button type="button" className="secondary" aria-label="הקטנת טקסט בשיתוף" disabled={textSize<=3.4} onClick={()=>setTextSize(v=>Math.max(3.4,v-.6))}><Minus size={18}/></button>
        <span>גודל הטקסט</span>
        <button type="button" className="secondary" aria-label="הגדלת טקסט בשיתוף" disabled={textSize>=6.4} onClick={()=>setTextSize(v=>Math.min(6.4,v+.6))}><Plus size={18}/></button>
        <button type="button" className="secondary" aria-pressed={fullscreen} onClick={()=>void toggleFullscreen()}>{fullscreen?<Minimize size={18}/>:<Maximize size={18}/>}מסך מלא</button>
        {screenError&&<span role="status">{screenError}</span>}
      </div>}
    </header>
    <div className="ww-diary-grid">{all?children:parts[step]}</div>
    {!all && <nav className="diary-flow-navigation" aria-label="ניווט בחלקי היומן">
      <button type="button" className="secondary" disabled={step===0} onClick={()=>move(step-1)}><ArrowRight size={20} aria-hidden="true"/>הקודם</button>
      {step<parts.length-1?<button type="button" onClick={()=>move(step+1)}>הבא<ArrowLeft size={20} aria-hidden="true"/></button>:<button type="button" onClick={()=>{setAll(true);requestAnimationFrame(()=>root.current?.scrollIntoView({block:'start'}));}}>סקירת היומן<List size={20} aria-hidden="true"/></button>}
    </nav>}
  </div>;
}
