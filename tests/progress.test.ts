import {describe,it,expect} from 'vitest';import {weekOf,dueReviews,buildWeeklyPlan} from '../src/lib/progress';import type {Attempt,Profile} from '../src/lib/types';
const profile={weeklyHours:4,skillConfidence:{}} as Profile;
const attempt=(patch:Partial<Attempt>={}):Attempt=>({id:'a',exerciseId:'sql-1',skillId:'sql',answer:'',passed:true,feedback:'',hintsUsed:0,createdAt:'2026-10-20T08:00:00Z',mode:'practice',...patch});
describe('learning plans and recall',()=>{
 it('uses the Israel local date when finding a Monday boundary',()=>{expect(weekOf(new Date('2026-10-25T22:30:00Z'))).toBe('2026-10-26');});
 it('does not invent reviews without successful evidence',()=>{expect(dueReviews([],new Date('2026-10-25'))).toEqual([]);expect(dueReviews([attempt({passed:false})],new Date('2026-10-25'))).toEqual([]);expect(dueReviews([attempt({selfReported:true})],new Date('2026-10-25'))).toEqual([]);});
 it('extends recall after independent success and resets failures',()=>{const now=new Date('2026-10-21T09:00:00Z');expect(dueReviews([attempt()],now)).toHaveLength(1);expect(dueReviews([attempt(),attempt({id:'b',createdAt:'2026-10-21T08:00:00Z'})],now)).toHaveLength(0);expect(dueReviews([attempt(),attempt({passed:false,createdAt:'2026-10-21T08:00:00Z'})],new Date('2026-11-01'))).toEqual([]);});
 it('keeps initial plans within the selected time budget',()=>{for(const weeklyHours of [1,3,4,5]){const tasks=buildWeeklyPlan({...profile,weeklyHours},[],new Date('2026-10-21'));expect(tasks.reduce((s,t)=>s+t.minutes,0)).toBeLessThanOrEqual(weeklyHours*60);expect(tasks.every(t=>!t.done&&t.weekOf==='2026-10-19')).toBe(true);}});
 it('keeps planned identities stable within the week',()=>{expect(buildWeeklyPlan(profile,[],new Date('2026-10-21')).map(t=>t.id)).toEqual(buildWeeklyPlan(profile,[],new Date('2026-10-22')).map(t=>t.id));});
});
