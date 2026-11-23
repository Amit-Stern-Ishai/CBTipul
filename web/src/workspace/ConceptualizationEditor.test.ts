import {describe,it,expect} from 'vitest';
import {ConsentError} from '../data/consent';
import {ApiError} from '../data/api';
import {conceptSuggestionError} from './ConceptualizationEditor';
describe('conceptualization suggestion errors',()=>{
 it('distinguishes failed consent lookup from missing acceptance',()=>{
  expect(conceptSuggestionError(new ConsentError('consent_lookup'))).toContain('לא הצלחנו לבדוק');
  expect(conceptSuggestionError(new ConsentError('consent'))).toContain('יש לאשר');
  expect(conceptSuggestionError(new ConsentError('consent_unavailable'))).toContain('אינה זמינה');
 });
 it('retains actionable allowance, rate and access messages',()=>{
  expect(conceptSuggestionError(new ApiError('quota'))).toContain('מכסת');
  expect(conceptSuggestionError(new ApiError('rate_limit'))).toContain('המתינו');
  expect(conceptSuggestionError(new ApiError('access'))).toContain('אין הרשאה');
 });
});
