import { useEffect, useRef, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { consents, ConsentError } from '../data/consent';
import copy from '../ai-data-sharing-consent.json';

/** Mounted only inside the authenticated private therapist route. */
export function AIConsentPrompt({account}: {account: string}) {
  const location = useLocation();
  const [open, setOpen] = useState(false), [busy, setBusy] = useState(false), [error, setError] = useState(false);
  const waiting = useRef<{resolve:()=>void; reject:(error:Error)=>void}[]>([]);
  const dialog = useRef<HTMLDialogElement>(null);
  const epoch = useRef(0);
  useEffect(() => {
    const present = () => new Promise<void>((resolve,reject) => { waiting.current.push({resolve,reject}); setError(!!consents.snapshot(account,'ai_data_sharing').error); setOpen(true); });
    consents.presentAI = present;
    return () => {
      epoch.current++; setBusy(false);
      if(consents.presentAI===present) consents.presentAI = undefined;
      waiting.current.splice(0).forEach(w=>w.reject(new ConsentError('stale')));
      setOpen(false);
    };
  },[account, location.pathname]);
  useEffect(()=>{if(open)dialog.current?.showModal();else dialog.current?.close();},[open]);
  function finish(accepted:boolean) {
    waiting.current.splice(0).forEach(w=>accepted?w.resolve():w.reject(new ConsentError('consent')));
    setOpen(false);
  }
  async function accept() {
    const started = epoch.current;
    setBusy(true);setError(false);
    try {
      const state=consents.snapshot(account,'ai_data_sharing');
      const receipt=state.pending ? await consents.retry(account,'ai_data_sharing') : await consents.decide(account,'ai_data_sharing','accepted');
      if(started !== epoch.current) return;
      if(receipt.status==='accepted')finish(true);else setError(true);
    } catch {if(started === epoch.current)setError(true);} finally {if(started === epoch.current)setBusy(false);}
  }
  return <dialog ref={dialog} className="ai-consent-dialog" dir="rtl" aria-labelledby="ai-consent-title" onCancel={e=>{e.preventDefault();if(!busy)finish(false);}}>
    <h2 id="ai-consent-title">{copy.title}</h2>
    <p style={{whiteSpace:'pre-line'}}>{copy.body}</p>
    {error&&<p role="alert">לא ניתן לאשר את ההסכמה כרגע. אפשר לנסות שוב או להמשיך לעבוד ידנית.</p>}
    <div className="actions"><button disabled={busy} onClick={()=>void accept()}>{busy?'בודק…':error?'ניסיון נוסף':copy.accept}</button><button disabled={busy} onClick={()=>finish(false)}>{copy.decline}</button></div>
  </dialog>;
}
