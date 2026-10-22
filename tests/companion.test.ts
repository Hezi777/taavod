import {describe,it,expect} from "vitest";
import {liveliness,blinkScale} from "@/lib/companion/bloub/face";

describe("Bloub facial life for Hen's portrait",()=>{
 it("changes eyelids over time and remains deterministic when replayed",()=>{
  const samples=Array.from({length:300},(_,i)=>liveliness(i/30));
  expect(samples.some(frame=>frame.lid<.2)).toBe(true);
  expect(samples.some(frame=>frame.lid===1)).toBe(true);
  expect(liveliness(1.48)).toEqual(liveliness(1.48));
  expect(blinkScale(liveliness(1.48).lid)).toBeLessThan(.2);
 });
 it("provides a motion-free pose for reduced motion",()=>{
  const frame=liveliness(7.5,{wander:0,blink:false,float:false});
  for(const key of ["dYaw","dPitch","dRoll","driftX","driftY"] as const)expect(Math.abs(frame[key])).toBe(0);
  expect(frame.lid).toBe(1);expect(frame.breath).toBe(1);
 });
});
