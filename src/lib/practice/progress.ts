import type { Attempt } from '@/lib/types';
import {dueReviews} from '@/lib/progress';
import { tracks, type Exercise } from '@/lib/curriculum';
export function latestAttempts(attempts: Attempt[]) {
 const latest = new Map<string, Attempt>();
 for (const attempt of [...attempts].sort((a,b)=>a.createdAt.localeCompare(b.createdAt))) latest.set(attempt.exerciseId,attempt);
 return latest;
}
export function nextReviewDate(exerciseId: string, attempts: Attempt[], now = new Date()): string {
 const successful = attempts.filter(a=>a.exerciseId===exerciseId && a.passed===true && a.hintsUsed===0 && !a.selfReported).length;
 const days = [1,3,7,14,30][Math.min(Math.max(successful-1,0),4)];
 return new Date(now.getTime()+days*86400000).toISOString().slice(0,10);
}
export function dueExercises(attempts: Attempt[], now = new Date()): Exercise[] {
 const due = new Set(dueReviews(attempts,now).map(item=>item.exerciseId));
 return tracks.flatMap(t=>t.exercises).filter(exercise=>due.has(exercise.id));
}
export function skillProgress(skillId: string, attempts: Attempt[]) {
 const track=tracks.find(t=>t.id===skillId);
 const latest=latestAttempts(attempts);
 const completed=track?.exercises.filter(e=>latest.get(e.id)?.passed===true && latest.get(e.id)?.hintsUsed===0 && !latest.get(e.id)?.selfReported).length??0;
 const reviewed=track?.exercises.filter(e=>latest.get(e.id)?.selfReported).length??0;
 const total=track?.exercises.length??0;
 return {completed,reviewed,total,percent:total?Math.round(completed/total*100):0};
}
export const diagnosticExercises = tracks.map(track => track.exercises.find(e=>e.kind==='quiz') ?? track.exercises.find(e=>e.kind==='sql') ?? track.exercises[0]);
