vi.mock('./clinical-save',()=>({clinicalSave:{save:vi.fn()}}));
import {clinicalSave} from './clinical-save';
import {beforeEach,describe,expect,it,vi} from 'vitest';
const f=vi.hoisted(()=>({from:vi.fn(),invoke:vi.fn(),guard:vi.fn(),rows:vi.fn(),require:vi.fn(),anonymize:vi.fn(),done:vi.fn(),refuse:vi.fn()}));
vi.mock('./client',()=>({supabase:{from:f.from,functions:{invoke:f.invoke}}}));
vi.mock('./api',()=>({ApiError:class extends Error{constructor(public code:string){super(code);}},guard:f.guard,rows:f.rows,workspaceAccount:()=> 'account',workspaceClinicalAnonymizer:async()=>f.anonymize}));
vi.mock('./consent',()=>({consents:{require:f.require,refuse:f.refuse}}));
import {columns,decodeNamePage,editableContent,patientNames,recordHistory,saveRecord,savePatientSession,writeRecord} from './patient-workspace';
import {createWorksheet,type WorksheetType} from '../workspace/model';
function complete(type:WorksheetType){const x=createWorksheet(type);x.data=type==='questionnaire'?{gad7_answers:Array(7).fill(0),phq9_answers:Array(9).fill(0),interference_level:0}:{[type==='diary_three'?'situation':'event']:'שם סינתטי — בדיוק!',automatic_thoughts:type==='diary_three'?[{text:'מחשבה',beliefBefore:80,beliefAfter:20}]:['מחשבה'],feelings:type==='diary_three'?[{name:'עצב',intensityBefore:80,intensityAfter:20}]:[{name:'עצב',intensity:80}],thinking_errors:[],alternative_thoughts:type==='diary_three'?[{text:'חלופה',belief:70}]:['חלופה'],behaviour:'פעולה',physical_symptoms:''};return x;}
function database(result:unknown={data:{id:'entry',patient_id:'patient'},error:null}){const chain={update:vi.fn(),insert:vi.fn(),eq:vi.fn(),select:vi.fn(),single:vi.fn().mockResolvedValue(result)};for(const k of ['update','insert','eq','select'] as const)chain[k].mockReturnValue(chain);f.from.mockReturnValue(chain);return chain;}
beforeEach(()=>{vi.clearAllMocks();f.guard.mockResolvedValue(f.done);f.require.mockResolvedValue({status:'accepted'});f.anonymize.mockImplementation(async text=>`safe:${text}`);});
describe('patient workspace data boundaries',()=>{
 it('validates string revisions and nullable names',()=>{expect(decodeNamePage({names:[{patient_id:'ABC',name:null,revision:'9007199254740993',updated_at:null}],next_after:null}).names[0].patient_id).toBe('abc');expect(()=>decodeNamePage({names:[{patient_id:'a',name:'x',revision:1,updated_at:null}],next_after:null})).toThrow();});
 it('requires consent and paginates names',async()=>{f.invoke.mockResolvedValueOnce({data:{names:[{patient_id:'ABC',name:'שם סינתטי',revision:'1',updated_at:null}],next_after:'ABC'},error:null}).mockResolvedValueOnce({data:{names:[],next_after:null},error:null});expect(await patientNames('account')).toEqual({abc:'שם סינתטי'});expect(f.require).toHaveBeenCalledWith('account','patient_name_storage');expect(f.invoke.mock.calls[1][1].body).toEqual({operation:'list',after:'ABC',limit:100});});
 it('never calls names without consent',async()=>{f.require.mockRejectedValueOnce(new Error('consent'));await expect(patientNames('account')).rejects.toThrow();expect(f.invoke).not.toHaveBeenCalled();});
 it('shared reads exclude notes and relations',async()=>{f.invoke.mockResolvedValue({data:{records:[],next_cursor:null},error:null});await recordHistory('patient','questionnaire',true);const c=columns('questionnaire',true);expect(c).not.toMatch(/notes|\*|\(/);expect(c).toContain('id::text');expect(f.invoke).toHaveBeenCalledWith('load-questionnaires',{body:{patient_id:'patient',view:'shared',limit:100}});expect(f.rows).not.toHaveBeenCalled();});
 it.each(['diary_one','diary_two','diary_three'] as const)('updates %s unchanged without anonymization or identity fields',async type=>{const db=database();const item=complete(type);item.data.created_by='patient';await saveRecord('patient','entry',item,true,null);expect(db.update).toHaveBeenCalledWith(editableContent(item));expect(db.update.mock.calls[0][0]).not.toHaveProperty('created_by');expect(db.eq.mock.calls).toEqual([['id','entry'],['patient_id','patient']]);expect(db.insert).not.toHaveBeenCalled();expect(f.anonymize).not.toHaveBeenCalled();});
 it('does not write on processing failure',async()=>{database();f.anonymize.mockRejectedValueOnce(new Error('processing'));await expect(savePatientSession('patient',null,'2026-11-01','','raw')).rejects.toThrow();expect(f.from).not.toHaveBeenCalled();});
 it.each([null,{id:'wrong',patient_id:'patient'},{id:'entry',patient_id:'other'}])('rejects missing/wrong returned row %j',async data=>{database({data,error:null});await expect(saveRecord('patient','entry',complete('diary_one'),true,null)).rejects.toThrow();});
 it('marks uncertain insert with no automatic resend',async()=>{const db=database({data:null,error:{code:'',message:'network'}});await expect(saveRecord('patient',null,complete('diary_one'),true,null)).rejects.toMatchObject({code:'uncertain_create'});expect(db.insert).toHaveBeenCalledTimes(1);});
 it('known denial is not an uncertain save',async()=>{database({data:null,error:{code:'42501'}});await expect(saveRecord('patient',null,complete('diary_one'),true,null)).rejects.toMatchObject({code:'access'});});
 it('checks account generation before writing',async()=>{f.done.mockImplementationOnce(()=>{throw new Error('stale');});await expect(writeRecord('Sessions','patient',null,{},'id',f.done)).rejects.toThrow('stale');expect(f.from).not.toHaveBeenCalled();});
});

it('encrypted summaries preserve originals and loaded version without storage anonymization',async()=>{
 database();
 const baseline={id:'entry',patient_id:'patient',_version:'v1',notes:'old',structured_notes:{summary:'old'}};
 vi.mocked(clinicalSave.save).mockResolvedValueOnce({...baseline,notes:'  שם סינתטי!  ',_version:'v2'});
 await savePatientSession('patient','entry','2026-11-01','cbt','  שם סינתטי!  ','old',baseline);
 expect(clinicalSave.save).toHaveBeenLastCalledWith('save-session',baseline,{session_date:'2026-11-01',type:'cbt',notes:'  שם סינתטי!  '},expect.any(Function));
 expect(f.anonymize).not.toHaveBeenCalled();expect(f.from).not.toHaveBeenCalled();
});
it('encrypted save failure never falls back to direct writes',async()=>{
 database();vi.mocked(clinicalSave.save).mockRejectedValueOnce(new Error('record_changed'));
 const baseline={id:'entry',patient_id:'patient',_version:'v1'};
 await expect(savePatientSession('patient','entry','2026-11-01','cbt','draft','old',baseline)).rejects.toThrow('record_changed');expect(f.from).not.toHaveBeenCalled();
});
it('encrypted shared questionnaire strips private supplied notes before save adapter',async()=>{
 database();vi.mocked(clinicalSave.save).mockResolvedValueOnce({id:'entry',patient_id:'patient',_version:'v2'});
 const baseline={id:'entry',patient_id:'patient',_version:'v1',created_by:'therapist'};
 await saveRecord('patient','entry',complete('questionnaire'),true,null,{private:'sentinel'},baseline);
 const call=vi.mocked(clinicalSave.save).mock.calls.at(-1)!;expect(call[4]).toBe(true);expect(call[2]).not.toHaveProperty('notes');expect(call[2]).not.toHaveProperty('combined_notes');expect(f.anonymize).not.toHaveBeenCalled();expect(f.from).not.toHaveBeenCalled();
});
it('private questionnaire saves preserve original notes without legacy writes',async()=>{
 const baseline={id:'entry',patient_id:'patient',_version:'v1',created_by:'therapist'};
 await saveRecord('patient','entry',complete('questionnaire'),false,null,{gad7:['  original!  ']},baseline);
 expect(vi.mocked(clinicalSave.save).mock.calls.at(-1)![2].combined_notes).toEqual({gad7:['  original!  ']});
 expect(f.anonymize).not.toHaveBeenCalled();expect(f.from).not.toHaveBeenCalled();
});
