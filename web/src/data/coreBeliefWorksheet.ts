/** Domain content used by reading/editing and the patient's published copy. */
export interface CoreBeliefStatement { text: string; feelings: string; now: number|null; most: number|null; least: number|null }
export interface CoreBeliefWorksheet {
 oldBelief: CoreBeliefStatement; balancedBelief: CoreBeliefStatement;
 oldEvidence: string; alternativeInterpretations: string; balancedEvidence: string; experiments: string;
 finalOldRating: number|null; finalBalancedRating: number|null;
}
export interface CoreBeliefWorksheetRecord {
 patientId: string; document: CoreBeliefWorksheet|null; revision: string|null;
 updatedAt: string|null; publishedRevision: string|null; publishedAt: string|null;
}
export function emptyCoreBeliefWorksheet(): CoreBeliefWorksheet {
 const belief = ():CoreBeliefStatement => ({text:'',feelings:'',now:null,most:null,least:null});
 return {oldBelief:belief(),balancedBelief:belief(),oldEvidence:'',alternativeInterpretations:'',balancedEvidence:'',experiments:'',finalOldRating:null,finalBalancedRating:null};
}
/** Transport only: never use this flat shape as UI state. */
export interface CoreBeliefWorksheetDTO {
 old_belief: string;
 old_feelings: string;
 old_now: number|null;
 old_most: number|null;
 old_least: number|null;
 balanced_belief: string;
 balanced_feelings: string;
 balanced_now: number|null;
 balanced_most: number|null;
 balanced_least: number|null;
 old_evidence: string;
 alternative_interpretations: string;
 balanced_evidence: string;
 experiments: string;
 old_final: number|null;
 balanced_final: number|null;
}
const textKeys = ['old_belief','old_feelings','balanced_belief','balanced_feelings','old_evidence','alternative_interpretations','balanced_evidence','experiments'] as const;
const ratingKeys = ['old_now','old_most','old_least','balanced_now','balanced_most','balanced_least','old_final','balanced_final'] as const;
function object(value: unknown): Record<string,unknown> {
 if(!value || typeof value !== 'object' || Array.isArray(value))throw new Error('invalid_core_belief_document');
 return value as Record<string,unknown>;
}
function dto(value:unknown):CoreBeliefWorksheetDTO {
 const row=object(value);
 if(Object.keys(row).length!==16 || !textKeys.every(k=>typeof row[k]==='string' && row[k].length<=10000) ||
 !ratingKeys.every(k=>row[k]===null || typeof row[k]==='number' && Number.isInteger(row[k]) && row[k]>=0 && row[k]<=100))throw new Error('invalid_core_belief_document');
 return row as unknown as CoreBeliefWorksheetDTO;
}
export function encodeCoreBeliefWorksheet(value:CoreBeliefWorksheet):CoreBeliefWorksheetDTO {
 return dto({
  old_belief:value.oldBelief.text,
  old_feelings:value.oldBelief.feelings,
  old_now:value.oldBelief.now,
  old_most:value.oldBelief.most,
  old_least:value.oldBelief.least,
  balanced_belief:value.balancedBelief.text,
  balanced_feelings:value.balancedBelief.feelings,
  balanced_now:value.balancedBelief.now,
  balanced_most:value.balancedBelief.most,
  balanced_least:value.balancedBelief.least,
  old_evidence:value.oldEvidence,
  alternative_interpretations:value.alternativeInterpretations,
  balanced_evidence:value.balancedEvidence,
  experiments:value.experiments,
  old_final:value.finalOldRating,
  balanced_final:value.finalBalancedRating,
 });
}
export function decodeCoreBeliefWorksheet(value:unknown):CoreBeliefWorksheet {
 const row=dto(value);
 return {
  oldBelief:{text:row.old_belief,feelings:row.old_feelings,now:row.old_now,most:row.old_most,least:row.old_least},
  balancedBelief:{text:row.balanced_belief,feelings:row.balanced_feelings,now:row.balanced_now,most:row.balanced_most,least:row.balanced_least},
  oldEvidence:row.old_evidence,
  alternativeInterpretations:row.alternative_interpretations,
  balancedEvidence:row.balanced_evidence,
  experiments:row.experiments,
  finalOldRating:row.old_final,
  finalBalancedRating:row.balanced_final,
 };
}
export function decodeCoreBeliefWorksheetRecord(value:unknown):CoreBeliefWorksheetRecord {
 const row=object(value);
 const nullable=(key:string, optional=false):string|null=>{
  const v=row[key]; if(v===null || optional && v===undefined)return null;
  if(typeof v!=='string')throw new Error('invalid_core_belief_record'); return v;
 };
 if(typeof row.patient_id!=='string')throw new Error('invalid_core_belief_record');
 return {patientId:row.patient_id,document:row.document===null?null:decodeCoreBeliefWorksheet(row.document),
  revision:nullable('revision'),updatedAt:nullable('updated_at',true),publishedRevision:nullable('published_revision',true),publishedAt:nullable('published_at')};
}
