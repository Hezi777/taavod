import {describe,it,expect} from "vitest";
import {createPortraitAnimation} from "@/lib/companion/portrait-animation";

describe("approved portrait driven by Bloub",()=>{
 it("uses Bloub's wink then returns to the current task expression",()=>{
  const rig=createPortraitAnimation();rig.react(.1);
  const wink=rig.sample(.7);expect(wink.state).toBe("wink");expect(wink.rightClosure).toBeGreaterThan(.95);
  rig.setMood("focus",.8);expect(rig.sample(2).state).toBe("idle");
 });
 it("follows a pointer through Bloub's interpolated look and releases it",()=>{
  const rig=createPortraitAnimation();rig.look(1,-1,1);
  const moving=rig.sample(1.08),arrived=rig.sample(1.5);
  expect(arrived.gazeX).toBeCloseTo(1);expect(arrived.gazeY).toBeCloseTo(-1);expect(moving.gazeX).toBeLessThan(arrived.gazeX);
  rig.release(2);expect(Math.abs(rig.sample(3).gazeX)).toBeLessThan(.6);
 });
 it("produces changing mouth shapes from Bloub's thinking pulse",()=>{
  const rig=createPortraitAnimation();rig.setMood("speaking",0);
  const openings=Array.from({length:60},(_,i)=>rig.sample(i/30).mouth);
  expect(Math.max(...openings)-Math.min(...openings)).toBeGreaterThan(.5);
 });
 it("keeps the approved neutral portrait unchanged with reduced motion",()=>{
  const rig=createPortraitAnimation();rig.setMood("celebrate",0);rig.look(1,1,.1);rig.react(.2);
  const pose=rig.sample(1,true);expect(pose.leftClosure).toBe(0);expect(pose.rightClosure).toBe(0);expect(pose.mouth).toBe(0);expect(pose.roll).toBe(0);expect(pose.gazeX).toBe(0);expect(pose.gazeY).toBe(0);expect(pose.breath).toBe(1);
 });
});
