import {describe,it,expect} from 'vitest';
import {emptyCoreBeliefWorksheet,encodeCoreBeliefWorksheet,decodeCoreBeliefWorksheet,decodeCoreBeliefWorksheetRecord} from './coreBeliefWorksheet';
describe('dedicated CoreBeliefWorksheet contract',()=>{
 it('round trips all 16 keys including eight explicit null ratings',()=>{
  const value=emptyCoreBeliefWorksheet(), encoded=JSON.parse(JSON.stringify(encodeCoreBeliefWorksheet(value)));
  expect(Object.keys(encoded)).toHaveLength(16);
  for(const k of ['old_now','old_most','old_least','balanced_now','balanced_most','balanced_least','old_final','balanced_final'])expect(encoded[k]).toBeNull();
  expect(decodeCoreBeliefWorksheet(encoded)).toEqual(value);
 });
 it('preserves zero and independently maps every field',()=>{
  const value={oldBelief:{text:'ישן',feelings:'חשש',now:0,most:91,least:null},balancedBelief:{text:'מאוזן',feelings:'תקווה',now:12,most:null,least:0},oldEvidence:'ראיות',alternativeInterpretations:'חלופה',balancedEvidence:'עבר',experiments:'ניסוי',finalOldRating:0,finalBalancedRating:100};
  const encoded=JSON.parse(JSON.stringify(encodeCoreBeliefWorksheet(value)));
  expect(encoded).toEqual({old_belief:'ישן',old_feelings:'חשש',old_now:0,old_most:91,old_least:null,balanced_belief:'מאוזן',balanced_feelings:'תקווה',balanced_now:12,balanced_most:null,balanced_least:0,old_evidence:'ראיות',alternative_interpretations:'חלופה',balanced_evidence:'עבר',experiments:'ניסוי',old_final:0,balanced_final:100});
  expect(decodeCoreBeliefWorksheet(encoded)).toEqual(value);
 });
 it('keeps absent document distinct from a new blank draft and metadata outside content',()=>{
  expect(decodeCoreBeliefWorksheetRecord({patient_id:'p',document:null,revision:null,published_at:null})).toEqual({patientId:'p',document:null,revision:null,publishedAt:null,updatedAt:null,publishedRevision:null});
  const record=decodeCoreBeliefWorksheetRecord({patient_id:'p',document:encodeCoreBeliefWorksheet(emptyCoreBeliefWorksheet()),revision:'opaque-A',updated_at:'updated',published_revision:'opaque-A',published_at:'sent'});
  expect(record.document).toEqual(emptyCoreBeliefWorksheet());expect(record).toMatchObject({revision:'opaque-A',updatedAt:'updated',publishedRevision:'opaque-A',publishedAt:'sent'});
  const edit=structuredClone(record.document!);edit.oldBelief.text='B';expect(record.document!.oldBelief.text).toBe('');
  expect(edit.balancedBelief.text).toBe('');
 });
 it('rejects malformed and missing ratings without coercion',()=>{
  const dto=encodeCoreBeliefWorksheet(emptyCoreBeliefWorksheet());
  for(const bad of [-1,101,0.5,'0',false,undefined])expect(()=>decodeCoreBeliefWorksheet({...dto,old_now:bad})).toThrow();
  expect(()=>decodeCoreBeliefWorksheet({...dto,extra:0})).toThrow();
  expect(()=>encodeCoreBeliefWorksheet({...emptyCoreBeliefWorksheet(),finalOldRating:101})).toThrow();
  expect(()=>decodeCoreBeliefWorksheetRecord({patient_id:'p',revision:null,published_at:null})).toThrow();
 });
});
