import {supabase} from './client';
import {guard,workspaceAccount,ApiError} from './api';
export const conceptualSections = [['childhood_experiences','חוויות ילדות'],['core_beliefs','אמונת יסוד'],['assumptions','הנחות בסיס'],['rules','חוקים וכללים'],['biased_expectations','ציפיות מוטות']] as const;
export type ConceptDocument = Record<typeof conceptualSections[number][0],string[]>;
export type ConceptRecord = {patient_id:string;document:ConceptDocument|null;revision:string|null;published_at:string|null;published_revision?:string|null;updated_at?:string|null};
export const emptyConcept = ():ConceptDocument => ({childhood_experiences:[],core_beliefs:[],assumptions:[],rules:[],biased_expectations:[]});
export function validConcept(value:unknown):value is ConceptDocument {
 return !!value && typeof value==='object' && conceptualSections.every(([key])=>{const rows=(value as ConceptDocument)[key];return Array.isArray(rows)&&rows.length<=30&&rows.every(s=>typeof s==='string'&&s.trim().length>0&&Array.from(s).length<=1500);});
}
export function conceptBody(action:'load_draft'|'save'|'publish',patient:string,revision:string|null=null,document?:ConceptDocument) {
 if(action==='save'&& !validConcept(document))throw new ApiError('invalid');
 if(action==='publish'&&!revision)throw new ApiError('invalid');
 return {action,patient_id:patient,...(action==='load_draft'?{}:{expected_revision:revision}),...(action==='save'?{document}: {})};
}
export async function conceptualization(action:'load_draft'|'save'|'publish',patient:string,revision:string|null=null,document?:ConceptDocument):Promise<ConceptRecord> {
 const account=workspaceAccount(),done=await guard(action!=='load_draft');
 const {data,error}=await supabase.functions.invoke('patient-conceptualization',{body:conceptBody(action,patient,revision,document)});
 done();if(account!==workspaceAccount())throw new ApiError('stale');
 if(error){let code='failed';try {const body=await error.context?.json();if(error.context?.status===409&&body?.error==='revision_conflict')code='revision_conflict';else if(error.context?.status===403)code='access';}catch{/* no response-body logging */}throw new ApiError(code);}
 if(!data||data.patient_id?.toLowerCase()!==patient.toLowerCase()||!(data.document===null||validConcept(data.document))||!(data.revision===null||typeof data.revision==='string'&&data.revision.length>0)||data.document!==null&&data.revision===null)throw new ApiError('failed');
 return data;
}
