import {describe,it,expect} from 'vitest';
import {conceptBody,emptyConcept,validConcept} from './conceptualization';
describe('conceptualization contract',()=>{
 it('sends every section and explicit first-save null; treats revisions as opaque',()=>{
  const a={...emptyConcept(),core_beliefs:['A']};expect(conceptBody('save','p',null,a)).toEqual({action:'save',patient_id:'p',expected_revision:null,document:a});
  expect(conceptBody('save','p','opaque',a).expected_revision).toBe('opaque');expect(conceptBody('publish','p','opaque')).not.toHaveProperty('document');expect(()=>conceptBody('publish','p',null)).toThrow();
 });
 it('allows empty lists, rejects blank, overlong and too many statements',()=>{
  expect(validConcept(emptyConcept())).toBe(true);expect(validConcept({...emptyConcept(),rules:[' ']})).toBe(false);expect(validConcept({...emptyConcept(),rules:['א'.repeat(1501)]})).toBe(false);expect(validConcept({...emptyConcept(),rules:Array(31).fill('א')})).toBe(false);
 });
});
