import { beforeEach, describe, expect, it, vi } from "vitest";
const mocked=vi.hoisted(()=>({records:[] as {kind:string;id:string;payload:Record<string,unknown>}[],ranges:[] as number[][],orders:[] as string[],filters:[] as string[][]}));
vi.mock("server-only",()=>({}));
vi.mock("../src/lib/server/config",()=>({localMode:()=>false}));
vi.mock("../src/lib/server/auth",()=>({sessionClient:async()=>({from:()=>{
  const builder={select:()=>builder,eq:(key:string,value:string)=>{mocked.filters.push([key,value]);return builder},order:(key:string)=>{mocked.orders.push(key);return builder},range:async(start:number,end:number)=>{mocked.ranges.push([start,end]);return {data:mocked.records.slice(start,end+1),error:null}},maybeSingle:async()=>({data:mocked.records[0]||null,error:null})};
  return builder;
}})}));
import { getRecord, listRecords } from "../src/lib/server/records";

describe("cloud record pagination",()=>{
  beforeEach(()=>{mocked.records=[];mocked.ranges=[];mocked.orders=[];mocked.filters=[]});
  it("loads more than Supabase's default 1000 rows using stable bounded pages",async()=>{
    mocked.records=Array.from({length:1243},(_,i)=>({kind:"jobs",id:String(i),payload:{id:String(i)}}));
    const records=await listRecords("owner");expect(records).toHaveLength(1243);expect(new Set(records.map(r=>r.id)).size).toBe(1243);
    expect(mocked.ranges).toEqual([[0,499],[500,999],[1000,1499]]);expect(mocked.orders.slice(0,3)).toEqual(["created_at","kind","id"]);expect(mocked.filters.every(([key,value])=>key==="user_id"&&value==="owner")).toBe(true);
  });
  it("reads a single owned record efficiently instead of fetching the library",async()=>{
    mocked.records=[{kind:"jobs",id:"one",payload:{id:"one"}}];
    expect((await getRecord("owner","jobs","one"))?.id).toBe("one");expect(mocked.ranges).toEqual([]);expect(mocked.filters).toEqual([["user_id","owner"],["kind","jobs"],["id","one"]]);
  });
  it("returns undefined for missing records",async()=>{expect(await getRecord("owner","jobs","missing")).toBeUndefined()});
});
