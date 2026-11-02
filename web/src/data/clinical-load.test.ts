import {beforeEach,expect,it,vi} from 'vitest';
const {invoke}=vi.hoisted(()=>({invoke:vi.fn()}));
vi.mock('./client',()=>({supabase:{functions:{invoke}}}));
import {loadClinical} from './clinical-load';
const row={id:'9223372036854775807',patient_id:'patient',session_id:null,_version:'opaque',notes:'',combined_notes:{gad7:['',null],phq9:[],interference:null}};
beforeEach(()=>invoke.mockReset());
it('follows short pages, preserves strings, version and exact JSON',async()=>{
 invoke.mockResolvedValueOnce({data:{records:[row],next_cursor:'next'}}).mockResolvedValueOnce({data:{records:[],next_cursor:null}});
 expect(await loadClinical('load-questionnaires',{patient_id:'patient'})).toEqual([row]);
 expect(invoke.mock.calls[1][1].body).toEqual({patient_id:'patient',limit:100,cursor:'next'});
});
it('fails rather than returning a partial load',async()=>{
 invoke.mockResolvedValueOnce({data:{records:[row],next_cursor:'next'}}).mockResolvedValueOnce({error:new Error('offline')});
 await expect(loadClinical('load-questionnaires')).rejects.toThrow('offline');
});
it('discards a response after account/patient invalidation',async()=>{
 let current=true;invoke.mockImplementation(async()=>{current=false;return {data:{records:[row],next_cursor:null}}});
 await expect(loadClinical('load-questionnaires',{},()=>{if(!current)throw new Error('stale')})).rejects.toThrow('stale');
});
it('sends shared purpose and rejects leaked private notes',async()=>{
 invoke.mockResolvedValue({data:{records:[row],next_cursor:null}});
 await expect(loadClinical('load-questionnaires',{view:'shared'})).rejects.toThrow('private_clinical_response');
 expect(invoke.mock.calls[0][1].body.view).toBe('shared');
});
it('retains a safe shared record without merging private fields',async()=>{
 const shared={id:row.id,patient_id:'patient',_version:'v',gad7_answers:[0]};invoke.mockResolvedValue({data:{records:[shared],next_cursor:null}});
 expect(await loadClinical('load-questionnaires',{view:'shared'})).toEqual([shared]);
});
it.each([{...row,id:1},{...row,session_id:2},{...row,_version:null},{...row,patient_id:'other'}])('rejects malformed IDs/version or wrong patient',async bad=>{
 invoke.mockResolvedValue({data:{records:[bad],next_cursor:null}});await expect(loadClinical('load-questionnaires',{patient_id:'patient'})).rejects.toThrow();
});
it('rejects repeated cursors',async()=>{invoke.mockResolvedValue({data:{records:[],next_cursor:'again'}});await expect(loadClinical('load-patients')).rejects.toThrow('invalid_clinical_cursor');});
it('keeps explicit null distinct from empty',async()=>{invoke.mockResolvedValue({data:{records:[{...row,notes:null}],next_cursor:null}});expect((await loadClinical<typeof row>('load-questionnaires'))[0].notes).toBeNull();});
