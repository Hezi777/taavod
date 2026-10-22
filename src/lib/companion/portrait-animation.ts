import {BotEngine} from "./bloub/engine";
import {EXPRESSION_BY_ID,type ExpressionId} from "./bloub/expressions";
import {DOT_R,DOT_PEAK} from "./bloub/decor";
import {clamp} from "./bloub/math";
import {STATE_BY_ID} from "./bloub/states";

export type HeadMood="idle"|"focus"|"celebrate"|"retry"|"speaking";
const expressions:Record<HeadMood,ExpressionId>={idle:"attentif",focus:"curieux",celebrate:"heureux",retry:"confus",speaking:"attentif"};
function expression(mood:HeadMood){const original=EXPRESSION_BY_ID.get(expressions[mood])!;return {...original,gaze:{...original.gaze,yaw:0,pitch:0,roll:mood==="idle"||mood==="speaking"?0:original.gaze.roll}}}

/** Bloub owns time, gaze interpolation, expression transitions, blinks and pulses. */
export function createPortraitAnimation(){
 const engine=new BotEngine(100,"idle",null,expression("idle"));
 const pulses=new BotEngine(100,"thinking");
 const rest=new BotEngine(100,"idle",null,expression("idle"));
 let mood:HeadMood="idle",winkUntil=-1;
 function apply(now:number){engine.setState("idle",now);engine.setExpression(expression(mood),now)}
 return {
  setMood(next:HeadMood,now:number){if(next===mood)return;mood=next;if(winkUntil<now)apply(now)},
  look(x:number,y:number,now:number){engine.setLook({yaw:clamp(x,-1,1)*16,pitch:-clamp(y,-1,1)*13,mix:1,spin:0,wander:0},now)},
  release(now:number){engine.setLook(null,now)},
  react(now:number){engine.setState("wink",now);winkUntil=now+STATE_BY_ID.get("wink")!.duration},
  sample(now:number,reducedMotion=false){
   if(winkUntil>=0&&now>winkUntil){winkUntil=-1;apply(now)}
   const frame=reducedMotion?rest.sample(0):engine.sample(now),rig=frame.rig;
   const close=(index:number)=>1-clamp(rig.lid*(rig.eyes[index].h<.15?0:rig.eyes[index].h/.44));
   const pulseFrame=pulses.sample(now);
   const pulse=clamp(((pulseFrame.rig.sil.radii[0]||DOT_R)/DOT_R-1)/(DOT_PEAK-1));
   return {gazeX:reducedMotion?0:clamp(rig.gaze.yaw/16,-1,1),gazeY:reducedMotion?0:clamp(-rig.gaze.pitch/13,-1,1),roll:reducedMotion?0:rig.gaze.roll*Math.PI/180*.18,leftClosure:reducedMotion?0:close(0),rightClosure:reducedMotion?0:close(1),mouth:reducedMotion?0:mood==="speaking"?pulse:mood==="celebrate"?.65:0,breath:reducedMotion?1:rig.breath,offX:reducedMotion?0:rig.offX,offY:reducedMotion?0:rig.offY,thinkingDots:mood==="focus"?pulseFrame.dots:[],state:engine.state};
  }
 };
}
