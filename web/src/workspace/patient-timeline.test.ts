import {describe,it,expect} from 'vitest';
import {latestScore,monthDays,weekStart,dayKey,timelineEntries} from './patient-timeline';
describe('patient timeline',()=>{
 it('uses Sunday-first complete calendar weeks, including leap days',()=>{const days=monthDays(new Date(2024,1,1));expect(days[0]).toBe('2024-01-28');expect(days.at(-1)).toBe('2024-03-02');expect(days).toContain('2024-02-29');expect(weekStart('2024-02-29')).toBe('2024-02-25');});
 it('does not invent dates or accept normalized invalid dates',()=>{expect(dayKey(null)).toBeNull();expect(dayKey('2026-02-30')).toBeNull();expect(dayKey('2026-11-18T23:00:00Z')).toBe('2026-11-18');});
 it('preserves exact IDs and separate questionnaire scores, flags and diary types',()=>{const id='9007199254740993';const rows=timelineEntries([{id:'session',session_date:'2026-11-18',notes:''}],[{id,patient_id:'p',answered_date:null,gad7_answers:Array(7).fill(1),phq9_answers:Array(9).fill(1)}],[[{id:'d1',patient_id:'p',created_at:'2026-11-17T12:00:00Z'}],[],[{id:'d3',patient_id:'p',created_at:'2026-11-16'}]]);expect(rows).toHaveLength(5);expect(rows.filter(e=>e.kind==='questionnaire').map(e=>[e.id,e.day,e.score?.total])).toEqual([[id,null,7],[id,null,9]]);expect(rows.find(e=>e.title==='PHQ-9')?.flagged).toBe(true);expect(rows.find(e=>e.id==='d3')?.section).toBe('diary_three');expect(rows[0].hasNotes).toBe(false);});
});

describe('latest questionnaire headline',()=>{
 it('uses recording timestamps for same-day results, never lexical IDs',()=>{
  const rows=timelineEntries([],[{id:'9',patient_id:'p',answered_date:'2026-11-18',created_at:'2026-11-18T09:00:00Z',gad7_answers:Array(7).fill(0)},{id:'10',patient_id:'p',answered_date:'2026-11-18',created_at:'2026-11-18T10:00:00Z',gad7_answers:Array(7).fill(2)}],[]);
  expect(latestScore(rows,'GAD-7')?.id).toBe('10');
  rows.forEach(r=>{r.recordedAt=undefined;});
  expect(latestScore(rows,'GAD-7')).toBeUndefined();
 });
});
