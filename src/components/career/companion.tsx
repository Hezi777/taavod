"use client";
import Image from "next/image";
import {useEffect,useRef,useState} from "react";
import {Button} from "@/components/ui/button";
import type {HeadMood} from "@/lib/companion/portrait-animation";

type HeadController={setMood:(mood:HeadMood)=>void;react:()=>void;dispose:()=>void};
export function HenCompanion({mood="idle",compact=false}:{mood?:HeadMood;compact?:boolean}){
 const host=useRef<HTMLSpanElement>(null),controller=useRef<HeadController|null>(null),moodRef=useRef(mood);
 const [greeting,setGreeting]=useState(false),[animated,setAnimated]=useState(false);
 const timer=useRef<ReturnType<typeof setTimeout>|null>(null);
 useEffect(()=>{moodRef.current=mood;controller.current?.setMood(mood)},[mood]);
 useEffect(()=>{let cancelled=false;import("@/lib/companion/head-renderer").then(async({createHeadRenderer})=>{if(cancelled||!host.current)return;const created=await createHeadRenderer(host.current);if(cancelled){created.dispose();return}controller.current=created;created.setMood(moodRef.current);setAnimated(true)}).catch(()=>{/* Keep the approved artwork visible if graphics support is unavailable. */});return()=>{cancelled=true;controller.current?.dispose();controller.current=null;if(timer.current)clearTimeout(timer.current)}},[]);
 function hello(){controller.current?.react();setGreeting(true);if(timer.current)clearTimeout(timer.current);timer.current=setTimeout(()=>setGreeting(false),2400)}
 return <div className={`hen-companion companion-live ${compact?"companion-compact":""}`} data-mood={mood}>
  <Button variant="ghost" className="companion-touch relative" onClick={hello} aria-label="Say hello to your animated Hen companion">
   {!animated&&<Image src="/companion/hen-fade-neutral.png" alt="Hen’s approved clay portrait with short curls, faded sides and a trimmed beard" fill sizes={compact?"115px":"240px"} priority={!compact} unoptimized style={{objectFit:"contain"}}/>}
   <span ref={host} className="companion-canvas" role="img" aria-label="Hen’s animated clay portrait with short curls, faded sides and a trimmed beard" style={{opacity:animated?1:0}}/>
  </Button>
  <span className="companion-shadow" aria-hidden="true"/>
  <span role="status" className={`companion-hello ${greeting?"visible":""}`}>{greeting?"Hey! One small step today.":""}</span>
 </div>;
}
