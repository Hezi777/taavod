import type {Attempt,Profile,PlanTask} from './types';
import {tracks} from './curriculum';
export function localDay(now=new Date()){return new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Jerusalem',year:'numeric',month:'2-digit',day:'2-digit'}).format(now);}
export function weekOf(now=new Date()){const day=new Date(`${localDay(now)}T12:00:00Z`);day.setUTCDate(day.getUTCDate()-((day.getUTCDay()+6)%7));return day.toISOString().slice(0,10);}
export function dueReviews(attempts:Attempt[],now=new Date()){
 const groups=new Map<string,Attempt[]>();for(const a of attempts){const group=groups.get(a.exerciseId)||[];group.push(a);groups.set(a.exerciseId,group);}
 return [...groups.values()].map(group=>{const sorted=group.sort((a,b)=>a.createdAt.localeCompare(b.createdAt));const last=sorted.at(-1)!;if(last.passed!==true||last.selfReported)return null;const independent=sorted.filter(a=>a.passed===true&&a.hintsUsed===0&&!a.selfReported).length;const interval=[1,3,7,14,30][Math.min(Math.max(independent-1,0),4)];const due=new Date(new Date(last.createdAt).getTime()+interval*86400000);return due<=now?{exerciseId:last.exerciseId,skillId:last.skillId,dueAt:due.toISOString()}:null;}).filter((r):r is NonNullable<typeof r>=>r!==null);
}
export function buildWeeklyPlan(profile:Profile,attempts:Attempt[],now=new Date()):PlanTask[]{
 const week=weekOf(now),budget=Math.round(profile.weeklyHours*60),tasks:PlanTask[]=[];
 const add=(task:Omit<PlanTask,'id'|'done'|'weekOf'>)=>tasks.push({...task,id:`plan-${week}-${tasks.length}`,done:false,weekOf:week});
 for(const review of dueReviews(attempts,now).slice(0,2)){const exercise=tracks.flatMap(t=>t.exercises).find(e=>e.id===review.exerciseId);if(exercise)add({title:`Recall: ${exercise.title}`,minutes:Math.min(exercise.minutes,25),type:'review',skillId:review.skillId,exerciseId:review.exerciseId,href:`/practice?exercise=${review.exerciseId}`});}
 const ranked=[...tracks].sort((a,b)=>{const score=(id:string)=>{const tries=attempts.filter(at=>at.skillId===id);if(!tries.length)return profile.skillConfidence[id]||0;return tries.filter(at=>at.passed===true&&!at.selfReported).length/tries.length*5;};return score(a.id)-score(b.id);});
 for(const track of ranked.slice(0,2)){const exercise=track.exercises.find(e=>!attempts.some(a=>a.exerciseId===e.id&&a.passed===true))||track.exercises[0];if(exercise)add({title:exercise.title,description:track.title,minutes:45,type:'practice',skillId:track.id,exerciseId:exercise.id,href:`/practice?exercise=${exercise.id}`});}
 add({title:'Strengthen one project story',description:'Document the problem, your contribution and one validation check.',minutes:Math.min(60,Math.round(budget*.25)),type:'project',href:'/portfolio'});
 add({title:'Explain one BI decision aloud',description:'Practice a concise answer, then review against the rubric.',minutes:30,type:'interview',href:'/interviews'});
 let used=tasks.reduce((sum,t)=>sum+t.minutes,0);while(used>budget&&tasks.length>1){const last=tasks.at(-1)!;if(last.minutes>15){const delta=Math.min(last.minutes-15,used-budget);last.minutes-=delta;used-=delta;}else{tasks.pop();used-=last.minutes;}}
 return tasks;
}
