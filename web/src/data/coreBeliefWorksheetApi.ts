import {supabase} from './client';
import {guard,workspaceAccount,ApiError} from './api';
import {encodeCoreBeliefWorksheet,decodeCoreBeliefWorksheetRecord,type CoreBeliefWorksheet} from './coreBeliefWorksheet';
export type CoreBeliefAction='load_draft'|'save'|'publish'|'load_published';
export function coreBeliefBody(action:CoreBeliefAction,patient:string|null,revision:string|null,document:CoreBeliefWorksheet){
 if(action==='load_published')return {action};
 if(!patient || action==='publish'&&!revision)throw new ApiError('invalid');
 return {action,patient_id:patient,...(action==='load_draft'?{}:{expected_revision:revision}),...(action==='save'?{document:encodeCoreBeliefWorksheet(document)}:{})};
}
export async function coreBeliefRequest(action:CoreBeliefAction,patient:string,revision:string|null,document:CoreBeliefWorksheet){
 const owner=workspaceAccount(),done=await guard(action==='save'||action==='publish');
 const {data,error}=await supabase.functions.invoke('core-belief-restructuring',{body:coreBeliefBody(action,patient,revision,document)});
 done();if(owner!==workspaceAccount())throw new ApiError('stale');
 if(error){let code='failed';try{const body=await error.context?.json();if(error.context?.status===409&&body?.error==='revision_conflict')code='revision_conflict';else if([401,403].includes(error.context?.status))code='access';}catch{/* No clinical response logging. */}throw new ApiError(code);}
 const result=decodeCoreBeliefWorksheetRecord(data);
 if(result.patientId.toLowerCase()!==patient.toLowerCase() || result.document!==null&&!result.revision)throw new ApiError('failed');
 return result;
}
