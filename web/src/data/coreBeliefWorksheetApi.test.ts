import {describe,it,expect,vi,beforeEach} from 'vitest';
const mock=vi.hoisted(()=>({owner:'one',invoke:vi.fn()}));
vi.mock('./client',()=>({supabase:{functions:{invoke:mock.invoke}}}));
vi.mock('./api',()=>({guard:async()=>()=>{},workspaceAccount:()=>mock.owner,ApiError:class extends Error{constructor(public code:string){super(code);}}}));
import {coreBeliefBody,coreBeliefRequest} from './coreBeliefWorksheetApi';
import {emptyCoreBeliefWorksheet,encodeCoreBeliefWorksheet} from './coreBeliefWorksheet';
beforeEach(()=>{mock.owner='one';mock.invoke.mockReset();});
describe('core belief API boundary',()=>{
 it('uses full typed codec and opaque saved revision; published reads send no identity',()=>{
  const d=emptyCoreBeliefWorksheet();d.oldBelief.now=0;
  expect(coreBeliefBody('save','patient',null,d)).toMatchObject({expected_revision:null,document:{old_now:0,old_most:null}});
  const save=coreBeliefBody('save','patient',null,d);expect('document' in save && Object.keys(save.document!).length).toBe(16);
  expect(coreBeliefBody('publish','patient','opaque',d)).toEqual({action:'publish',patient_id:'patient',expected_revision:'opaque'});
  expect(coreBeliefBody('load_published','must-not-send','must-not-send',d)).toEqual({action:'load_published'});
  expect(()=>coreBeliefBody('publish','patient',null,d)).toThrow();
 });
 it('maps confirmed complete records without changing blank/zero',async()=>{
  const d=emptyCoreBeliefWorksheet();d.oldBelief.now=0;
  mock.invoke.mockResolvedValue({data:{patient_id:'patient',document:encodeCoreBeliefWorksheet(d),revision:'opaque',published_at:null,updated_at:null,published_revision:null},error:null});
  const result=await coreBeliefRequest('save','patient',null,d);
  expect(result.document).toEqual(d);expect(mock.invoke).toHaveBeenCalledWith('core-belief-restructuring',expect.anything());
 });
 it('keeps conflict and access failure explicit, with no fallback or retry',async()=>{
  for(const [status,error,code] of [[409,'revision_conflict','revision_conflict'],[403,'access_denied','access']] as const){
   mock.invoke.mockResolvedValue({data:null,error:{context:{status,json:async()=>({error})}}});
   await expect(coreBeliefRequest('save','patient','old',emptyCoreBeliefWorksheet())).rejects.toMatchObject({code});
  }expect(mock.invoke).toHaveBeenCalledTimes(2);
 });
 it('discards responses after account changes and rejects mismatched patient',async()=>{
  mock.invoke.mockImplementationOnce(async()=>{mock.owner='two';return {data:null,error:null};});
  await expect(coreBeliefRequest('load_draft','patient',null,emptyCoreBeliefWorksheet())).rejects.toMatchObject({code:'stale'});
  mock.invoke.mockResolvedValue({data:{patient_id:'other',document:null,revision:null,published_at:null},error:null});
  await expect(coreBeliefRequest('load_draft','patient',null,emptyCoreBeliefWorksheet())).rejects.toThrow();
 });
});
