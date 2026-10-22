"use client";
import Link from "next/link";
import { HenCompanion } from "@/components/career/companion";
import {useSearchParams} from "next/navigation";
import { Suspense, useState } from "react";
import { ArrowRight, ArrowUpRight, BookOpen, CalendarDays, Clock3, Code2, Plus, RotateCcw, Sparkles, Target } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { useCareer } from "@/lib/career-store";
import { getExercise, recommendLesson } from "@/lib/curriculum";
import { buildWeeklyPlan, dueReviews, weekOf } from "@/lib/progress";
import { EmptyState, LoadingState, SectionCard } from "@/components/career/shared";

export default function TodayPage(){return <Suspense fallback={<LoadingState/>}><TodayWorkspace/></Suspense>}
function TodayWorkspace(){
 const params=useSearchParams();
 const {profile,tasks,jobs,attempts,addTask,toggleTask,ready,mode,loadingError}=useCareer();
 const [adding,setAdding]=useState(()=>params.get("addTask")==="true"),[title,setTitle]=useState(""),[minutes,setMinutes]=useState(30);
 const [now]=useState(()=>new Date());
 const currentTasks=tasks.filter(task=>!task.weekOf||task.weekOf===weekOf(now));
 const completed=currentTasks.filter(task=>task.done),pending=currentTasks.filter(task=>!task.done),doneMinutes=completed.reduce((sum,task)=>sum+task.minutes,0),plannedMinutes=currentTasks.reduce((sum,task)=>sum+task.minutes,0),budget=profile.weeklyHours*60;
 const reviews=dueReviews(attempts,now);
 const followups=jobs.filter(job=>job.followUpDate&&!["rejected","withdrawn","archived"].includes(job.status)).sort((a,b)=>(a.followUpDate||"").localeCompare(b.followUpDate||""));
 const days=Math.max(0,Math.ceil((new Date(`${profile.targetDate}T00:00:00`).getTime()-now.getTime())/86400000));
 const greeting=new Intl.DateTimeFormat("en-GB",{weekday:"long",day:"numeric",month:"long",timeZone:"Asia/Jerusalem"}).format(new Date());
 async function saveTask(){if(!title.trim())return;await addTask({id:crypto.randomUUID(),title:title.trim(),minutes,done:false,type:"career",weekOf:weekOf(now)});setAdding(false);setTitle("")}
 async function refreshPlan(){for(const task of buildWeeklyPlan(profile,attempts,now)){if(!tasks.some(existing=>existing.id===task.id))await addTask(task)}setAdding(false)}
 if(!ready)return <LoadingState/>;
 const nextTask=pending[0];
 const nextExercise=nextTask?.exerciseId?getExercise(nextTask.exerciseId):undefined;
 const recommendation=recommendLesson(attempts);
 const firstSession=attempts.length===0;
 const focusTitle=firstSession?recommendation.lesson.title:nextTask?.title||"Find your starting point";
 const focusDescription=firstSession?recommendation.guide.goal:nextExercise?.prompt.split("\n\n")[0]||nextTask?.description;
 const focusMinutes=firstSession?recommendation.lesson.minutes+(recommendation.guide.exercise?.minutes??0):nextTask?.minutes||20;
 const focusHref=firstSession?`/learn?track=${recommendation.track.id}&lesson=${recommendation.lesson.id}`:nextTask?.href||"/practice?mode=assessment";
 return <div className="today-page">
  <div className="today-heading"><div><p className="today-date">{greeting}</p><h1>What will you work on today{profile.name?`, ${profile.name.split(" ")[0]}`:""}?</h1><p>A focused session now. A stronger story for your next BI role.</p></div></div>
  {loadingError&&<div className="local-banner" role="alert">{loadingError}<Link href="/settings">Check workspace<ArrowUpRight size={13}/></Link></div>}
  <section className="daily-focus"><div className="daily-focus-copy"><span className="focus-label"><span/>Your next session</span><h2>{focusTitle}</h2><p>{focusDescription||"A short diagnostic will help you refresh the right skills, without starting everything from scratch."}</p><div className="focus-meta"><span><Clock3 size={15}/>{focusMinutes} minutes</span><span><Target size={15}/>{profile.targetRoles[0]||"Your next role"}</span></div><div className="hero-actions"><Button asChild><Link href={focusHref}>{firstSession||nextTask?"Start this session":"Take the diagnostic"}<ArrowRight size={16}/></Link></Button><Button asChild variant="ghost"><Link href="/learn">Browse learning paths</Link></Button></div></div><div className="daily-companion"><HenCompanion mood={completed.length>0&&pending.length===0?"celebrate":"idle"}/><span>Your corner. Your pace.</span></div></section>
  <div className="today-primary-grid"><section className="weekly-route"><div className="weekly-header"><div className="weekly-title"><div><h2>This week</h2><p>{profile.weeklyHours} hours planned around your goals</p></div></div><Button size="sm" variant="outline" onClick={()=>setAdding(true)}><Plus size={14}/>Add task</Button></div><div className="week-progress"><div><span><strong>{Math.round(doneMinutes/60*10)/10}</strong> of {profile.weeklyHours} hours complete</span><small>{completed.length} / {currentTasks.length} tasks</small></div><Progress value={Math.min(100,doneMinutes/budget*100)} aria-label="Weekly time complete"/></div>
   {reviews.length>0&&<div className="review-due-note"><RotateCcw size={13}/>{reviews.length} spaced {reviews.length===1?"review is":"reviews are"} ready.<Link href={`/practice?exercise=${reviews[0].exerciseId}`}>Review now<ArrowUpRight size={12}/></Link></div>}<div className="route-tasks">{currentTasks.length?currentTasks.map(task=><div className={`route-task ${task.done?"task-completed":""}`} key={task.id}><div className="route-line"><Checkbox checked={task.done} onCheckedChange={()=>toggleTask(task.id)} aria-label={`Mark ${task.title} ${task.done?"incomplete":"complete"}`}/></div><div className="route-task-copy"><Link href={task.href||"/practice"}><h3>{task.title}</h3></Link><div className="task-meta"><span>{task.type==="project"?"Portfolio":task.type==="practice"?"Practice":task.type==="review"?"Review":task.type==="interview"?"Interview":"Career"}</span><span><Clock3 size={12}/>{task.minutes} min</span></div></div><Button asChild size="icon" variant="ghost" aria-label={`Open ${task.title}`}><Link href={task.href||"/practice"}><ArrowUpRight size={17}/></Link></Button></div>):<EmptyState title="Make a little room for progress" description="Create a focused week from your current skill gaps and available time."/>}</div>
   <div className="weekly-foot"><span>{plannedMinutes>budget?"Your plan is over your weekly time budget.":`${Math.max(0,budget-plannedMinutes)} minutes available this week`}</span><Button size="sm" variant="ghost" onClick={refreshPlan}><Sparkles size={14}/>Suggest a plan</Button></div></section>
   <div className="today-side"><section className="direction-summary"><h2>Your direction</h2><h3>{profile.targetRoles[0]||"Your next role"}</h3><p>{profile.location}</p><div className="direction-date"><CalendarDays size={17}/><span>{new Date(`${profile.targetDate}T12:00:00`).toLocaleDateString("en-GB",{day:"numeric",month:"long",year:"numeric"})}<small>{days} days to prepare</small></span></div><Link href="/settings#profile">Review your goals<ArrowUpRight size={14}/></Link></section><section className="progress-summary"><h2>Practice so far</h2><div><span>Sessions completed</span><strong>{attempts.length}</strong></div><div><span>Exercises passed</span><strong>{attempts.filter(attempt=>attempt.passed===true&&!attempt.selfReported).length}</strong></div><p>Progress builds with practice. No streaks to keep up with.</p></section></div></div>
  <div className="today-bottom"><SectionCard title="Your career, in motion" description="Keep the next opportunity within reach."><div className="action-list"><Link href="/jobs"><span className="icon-tile"><Code2 size={19}/></span><div><strong>Your job pipeline</strong><p>{jobs.filter(job=>["saved","preparing","applied","interviewing","offer"].includes(job.status)).length} roles saved, preparing, or in progress</p></div><ArrowUpRight size={17}/></Link><Link href="/portfolio"><span className="icon-tile"><BookOpen size={19}/></span><div><strong>Build your evidence</strong><p>Project stories, career documents, and work you can show.</p></div><ArrowUpRight size={17}/></Link></div></SectionCard><SectionCard title="Follow-ups" description="Dates you set on the roles you care about." action={<Button asChild variant="ghost" size="sm"><Link href="/jobs">View jobs<ArrowUpRight size={14}/></Link></Button>}>{followups.length?<div className="followup-list">{followups.slice(0,3).map(job=><Link href={`/jobs?job=${job.id}`} key={job.id}><div className="company-initial">{job.company.charAt(0)}</div><div><strong>{job.title}</strong><p>{job.company}</p></div><span>{new Date(`${job.followUpDate}T12:00:00`).toLocaleDateString("en-GB",{day:"numeric",month:"short"})}</span></Link>)}</div>:<EmptyState title="You’re all caught up" description="Set a follow-up date on a saved job when there’s someone to check back with."/>}</SectionCard></div>
  <div className="saved-note"><span className="connection-dot"/>{mode==="cloud"?"Your progress is synced to your private workspace.":"Saved privately on your Mac."}<Link href="/coach">Need a hand? Ask your coach<ArrowUpRight size={13}/></Link></div>
  <Dialog open={adding} onOpenChange={setAdding}><DialogContent><DialogHeader><DialogTitle>Add a task</DialogTitle><DialogDescription>Add a realistic next step to this week’s plan.</DialogDescription></DialogHeader><div className="form-stack"><Label htmlFor="task-title">Task</Label><Input id="task-title" value={title} onChange={event=>setTitle(event.target.value)} placeholder="Practice window functions for 30 minutes"/><Label htmlFor="task-minutes">Time in minutes</Label><Input id="task-minutes" type="number" min={5} max={480} value={minutes} onChange={event=>setMinutes(Math.max(5,Number(event.target.value)))}/><Button onClick={saveTask} disabled={!title.trim()}>Add to my week<Plus size={15}/></Button><div className="info-note">Build a practice plan from your confidence, attempt history, and due reviews. Existing tasks stay in your plan.</div><Button variant="outline" onClick={refreshPlan}><Sparkles size={15}/>Add suggested tasks for this week</Button></div></DialogContent></Dialog>
 </div>
}
