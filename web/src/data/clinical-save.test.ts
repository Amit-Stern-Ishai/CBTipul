import {expect,it,vi} from 'vitest';
vi.mock('./client',()=>({supabase:{functions:{invoke:vi.fn()}}}));
vi.mock('./api',()=>({ApiError:class extends Error {constructor(public code:string){super(code)}}}));
import {ClinicalSave,sameClinicalValue} from './clinical-save';
const previous={id:'9223372036854775807',_version:'version-a',notes:null,combined_notes:{gad7:['original']},patient_id:'patient'};
const saved={...previous,_version:'version-b'};
const noop=()=>{};
it('preserves exact original text, clears, string IDs and version without merging questionnaire fields',async()=>{
 const invoke=vi.fn().mockResolvedValue({data:{record:saved}});const saver=new ClinicalSave(invoke);
 const text='  שם סינתטי!\nיחסים — בדיוק.  ';
 expect(await saver.save('save-questionnaire',previous,{notes:'',combined_notes:null,patient_id:'patient',unused:undefined},noop)).toEqual(saved);
 expect(invoke.mock.calls[0][1]).toEqual({mode:'update',id:previous.id,expected_version:'version-a',changes:{notes:'',combined_notes:null}});
 await saver.save('save-session',null,{patient_id:'patient',notes:text,type:'cbt'},noop);
 expect(invoke.mock.calls[1][1].changes.notes).toBe(text);
});
it('omits unchanged analysis while preserving an intentional analysis edit',async()=>{
 const invoke=vi.fn().mockResolvedValue({data:{record:saved}});const saver=new ClinicalSave(invoke);
 await saver.save('save-session',{...previous,structured_notes:{summary:'old'}},{notes:'new',structured_notes:{summary:'old'}},noop);
 expect(invoke.mock.calls[0][1].changes).toEqual({notes:'new'});
 await saver.save('save-session',previous,{structured_notes:{summary:'new'}},noop);
 expect(invoke.mock.calls[1][1].changes).toEqual({structured_notes:{summary:'new'}});
});
it('shared strips private proposals and rejects private responses',async()=>{
 const {notes,combined_notes,...shared}=saved;void notes;void combined_notes;
 const invoke=vi.fn().mockResolvedValueOnce({data:{record:shared}}).mockResolvedValueOnce({data:{record:saved}});const saver=new ClinicalSave(invoke);
 expect(await saver.save('save-questionnaire',previous,{notes:'secret',combined_notes:{secret:true},interference_level:1},noop,true)).toEqual(shared);
 expect(invoke.mock.calls[0][1]).toMatchObject({view:'shared',changes:{interference_level:1}});
 await expect(saver.save('save-questionnaire',previous,{},noop,true)).rejects.toThrow();
});
it('conflict and uncertain outcomes never retry or change the baseline',async()=>{
 const invoke=vi.fn().mockResolvedValueOnce({error:{context:{status:409,json:async()=>({error:'record_changed'})}}}).mockResolvedValueOnce({error:{context:{status:503,json:async()=>({error:'save_outcome_unknown'})}}}).mockRejectedValueOnce(new Error('lost'));
 const saver=new ClinicalSave(invoke);
 await expect(saver.save('save-session',previous,{notes:'draft'},noop)).rejects.toMatchObject({code:'record_changed'});
 await expect(saver.save('save-session',null,{notes:'draft'},noop)).rejects.toMatchObject({code:'uncertain_create'});
 await expect(saver.save('save-session',null,{notes:'draft'},noop)).rejects.toMatchObject({code:'uncertain_create'});
 expect(invoke).toHaveBeenCalledTimes(3);expect(previous._version).toBe('version-a');
});
it('rejects late account results and missing versions without dispatch',async()=>{
 let current=true;const invoke=vi.fn().mockImplementation(async()=>{current=false;return {data:{record:saved}}});const saver=new ClinicalSave(invoke);
 await expect(saver.save('save-session',previous,{notes:'draft'},()=>{if(!current)throw new Error('account_changed')})).rejects.toThrow('account_changed');
 await expect(saver.save('save-session',{id:'x'},{notes:'draft'},noop)).rejects.toMatchObject({code:'record_changed'});expect(invoke).toHaveBeenCalledTimes(1);
});

it('JSON object ordering is not a clinical change',()=>{expect(sameClinicalValue({a:1,b:[null,'']},{b:[null,''],a:1})).toBe(true);expect(sameClinicalValue(null,'')).toBe(false);});
it('lost HTTP response returned as an SDK error remains uncertain',async()=>{const invoke=vi.fn().mockResolvedValue({error:new Error('offline')});await expect(new ClinicalSave(invoke).save('save-session',null,{notes:'draft'},noop)).rejects.toMatchObject({code:'uncertain_create'});expect(invoke).toHaveBeenCalledTimes(1);});
