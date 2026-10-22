import {describe,it,expect} from 'vitest';
import {PGlite} from '@electric-sql/pglite';
import {tracks,allExercises,getLessonGuide,recommendLesson} from '../src/lib/curriculum';
import {sqlFixture} from '../src/lib/practice/fixtures';
import {equivalentResults,type ResultSet} from '../src/lib/practice/compare';
import {skillProgress,nextReviewDate} from '../src/lib/practice/progress';
import type {Attempt} from '../src/lib/types';

describe('curriculum integrity',()=>{
 it('includes ten substantive tracks and all 27 imported prompts',()=>{
  expect(tracks).toHaveLength(10);
  for(const track of tracks){expect(track.lessons.length).toBeGreaterThanOrEqual(3);expect(track.exercises.length).toBeGreaterThanOrEqual(6);for(const l of track.lessons){expect(l.paragraphs.join('').length).toBeGreaterThan(250);expect(l.source.url).toMatch(/^https:\/\//);}}
  expect(allExercises.filter(e=>e.id.startsWith('pagila-'))).toHaveLength(27);
  expect(new Set(allExercises.map(e=>e.id)).size).toBe(allExercises.length);
 });
 it('has executable quiz keys and explicit manual rubrics',()=>{for(const e of allExercises){if(e.kind==='quiz')expect(e.options?.[e.correctOption!]).toBe(e.solution);if(['written','external'].includes(e.kind))expect(e.rubric.length).toBeGreaterThan(0);}});
 it('links every teaching session to a relevant task without requiring a solution reveal',()=>{
  for(const track of tracks)for(const lesson of track.lessons){const guide=getLessonGuide(lesson.id);expect(guide?.exercise?.skillId,lesson.id).toBe(track.id);expect(guide?.steps).toHaveLength(3);expect(guide?.answer.length).toBeGreaterThan(40);}
  for(const exercise of allExercises.filter(item=>item.kind==='sql')){expect(exercise.prompt).toContain('Output columns, in order:');expect(exercise.prompt).not.toContain('shown in the reference');}
 });
 it('recommends an actionable first session, advances after practice and prioritizes a failed linked task',()=>{
  const first=recommendLesson([]);expect(first.lesson.id).toBe('sql-lesson-1');expect(first.guide.exercise?.id).toBe('pagila-querying-and-joins-5');
  const pass:Attempt={id:'start',exerciseId:first.guide.exercise!.id,skillId:'sql',answer:'',passed:true,hintsUsed:0,feedback:'',createdAt:'2026-10-21T12:00:00Z',mode:'practice'};
  expect(recommendLesson([pass]).lesson.id).toBe('sql-lesson-2');
  const failed:Attempt={...pass,id:'failed',exerciseId:'powerbi-filter-direction',skillId:'powerbi',passed:false};
  expect(recommendLesson([pass,failed]).lesson.id).toBe('powerbi-lesson-1');
  expect(recommendLesson([{...pass,passed:null}]).lesson.id).toBe('sql-lesson-1');
 });
});

describe('PostgreSQL fixture and reference execution',()=>{
 it('runs all reference queries against both fixtures, preserving real result semantics',async()=>{
  for(const variant of [0,1]){const db=await PGlite.create();try{await db.exec(sqlFixture(variant));for(const e of allExercises.filter(e=>e.kind==='sql')){const actual=await db.exec(e.solution);expect(actual.length,`${e.title} result`).toBeGreaterThan(0);expect(actual.some(s=>s.fields.length>0)).toBe(true);}}finally{await db.close();}}
 });
 it('accepts equivalent SQL with different aliases and rejects multiplication/deduping amounts',async()=>{
  const db=await PGlite.create();try{await db.exec(sqlFixture());const query=async(s:string)=>await db.exec(s) as ResultSet[];
   expect(equivalentResults(await query('SELECT SUM(amount) AS total FROM payment'),await query('SELECT SUM(p.amount) AS revenue FROM payment p'))).toBe(true);
   expect(equivalentResults(await query('SELECT SUM(DISTINCT amount) FROM payment'),await query('SELECT SUM(amount) FROM payment'))).toBe(false);
   const correct=await query('SELECT SUM(p.amount) FROM payment p JOIN rental r USING(rental_id) JOIN inventory i USING(inventory_id)');
   const wrong=await query('SELECT SUM(p.amount) FROM payment p JOIN rental r USING(rental_id) JOIN inventory i USING(inventory_id) JOIN film_actor fa USING(film_id)');
   expect(equivalentResults(wrong,correct)).toBe(false);
  }finally{await db.close();}
 });
 it('detects anomalies and rejects writes in a read-only transaction',async()=>{const db=await PGlite.create();try{await db.exec(sqlFixture(1));const result=await db.query<{n:number}>('SELECT COUNT(*)::int n FROM payment p LEFT JOIN rental r USING(rental_id) WHERE r.rental_id IS NULL');expect(result.rows[0].n).toBe(1);await db.exec('BEGIN; SET TRANSACTION READ ONLY;');await expect(db.exec('DELETE FROM payment')).rejects.toThrow(/read-only/);}finally{await db.close();}});
});

describe('practice evidence',()=>{
 const base:Attempt={id:'1',exerciseId:'python-1',skillId:'python',answer:'',passed:true,feedback:'',hintsUsed:0,createdAt:'2026-01-01T12:00:00Z',mode:'practice'};
 it('keeps self review and assisted practice separate from independent completion',()=>{expect(skillProgress('python',[base]).completed).toBe(1);expect(skillProgress('python',[{...base,hintsUsed:1}]).completed).toBe(0);expect(skillProgress('python',[{...base,selfReported:true}]).reviewed).toBe(1);});
 it('spaces successful independent reviews from one to three days',()=>{const now=new Date(base.createdAt);expect(nextReviewDate('python-1',[base],now)).toBe('2026-01-02');expect(nextReviewDate('python-1',[base,{...base,id:'2'}],now)).toBe('2026-01-04');});
});
