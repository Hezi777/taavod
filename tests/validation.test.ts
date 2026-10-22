import { describe, expect, it } from "vitest";
import { createJob } from "../src/lib/jobs";
import { emptyProfile } from "../src/lib/server/records";
import { validateRecord } from "../src/lib/validation";

describe("record validation",()=>{
  const profile=emptyProfile("owner-id","owner@example.com") as unknown as Record<string,unknown>;
  it("merges a partial edit with complete existing records",()=>{
    const result=validateRecord("profile",profile,{name:"New name",weeklyHours:3.5});expect(result.name).toBe("New name");expect(result.weeklyHours).toBe(3.5);expect(result.watchlist).toEqual([]);expect(result.email).toBe("owner@example.com");
  });
  it("rejects malformed arrays and nested watchlist items",()=>{
    expect(()=>validateRecord("profile",profile,{watchlist:{name:"A"}})).toThrow();
    expect(()=>validateRecord("profile",profile,{watchlist:[{id:"company",name:"A",feedType:"unsupported"}]})).toThrow();
    expect(()=>validateRecord("profile",profile,{targetRoles:[42]})).toThrow();
    expect(()=>validateRecord("profile",profile,{skillConfidence:{sql:50}})).toThrow();
  });
  it("prevents executable links in profile, project and task destinations",()=>{
    expect(()=>validateRecord("profile",profile,{linkedin:"javascript:alert(1)"})).toThrow();
    expect(()=>validateRecord("profile",profile,{github:"https://user:password@example.com"})).toThrow();
    const task={id:"task",title:"Practice",minutes:15,done:false,type:"practice",href:"/practice?track=sql"};
    expect(validateRecord("tasks",undefined,task).href).toBe("/practice?track=sql");
    expect(()=>validateRecord("tasks",undefined,{...task,href:"javascript:alert(1)"})).toThrow();
    expect(()=>validateRecord("tasks",undefined,{...task,href:"//example.com"})).toThrow();
    expect(()=>validateRecord("tasks",undefined,{...task,href:"/\\example.com"})).toThrow();
  });
  it("requires a complete new row and strips privileged or unknown properties",()=>{
    expect(()=>validateRecord("jobs",undefined,{id:"job",title:"BI Developer"})).toThrow();
    const result=validateRecord("profile",profile,{name:"Owner",integrations:[{apiKey:"no"}],user_id:"foreign",unrecognized:true});
    expect(result).not.toHaveProperty("integrations");expect(result).not.toHaveProperty("user_id");expect(result).not.toHaveProperty("unrecognized");
  });
  it("validates the resulting job stage without destroying historical source dates",()=>{
    const job=createJob({capturedAt:"",postedAt:"2 weeks ago",historical:true}) as unknown as Record<string,unknown>;
    const result=validateRecord("jobs",job,{notes:"Follow up",followUpDate:""});expect(result.postedAt).toBe("2 weeks ago");expect(result.capturedAt).toBe("");expect(result.followUpDate).toBe("");
    expect(()=>validateRecord("jobs",job,{status:"maybe"})).toThrow();expect(()=>validateRecord("jobs",job,{skills:"SQL"})).toThrow();
  });
  it("bounds payload strings and preserves nested provenance",()=>{
    const job=createJob({raw:{legacyFitNotes:"Unverified old note"}}) as unknown as Record<string,unknown>;
    expect(validateRecord("jobs",job,{notes:"Useful"}).raw).toEqual({legacyFitNotes:"Unverified old note"});
    expect(()=>validateRecord("jobs",job,{description:"a".repeat(120001)})).toThrow();expect(()=>validateRecord("profile",profile,{weeklyHours:-1})).toThrow();
  });
  it("accepts reviewed practice and rejects fabricated modes or negative hint counts",()=>{
    const attempt={id:"attempt",exerciseId:"sql-query",skillId:"sql",answer:"select 1",passed:true,feedback:"Correct",hintsUsed:0,createdAt:new Date().toISOString(),mode:"practice"};
    expect(validateRecord("attempts",undefined,attempt).passed).toBe(true);
    expect(()=>validateRecord("attempts",undefined,{...attempt,hintsUsed:-1})).toThrow();expect(()=>validateRecord("attempts",undefined,{...attempt,mode:"unknown"})).toThrow();
  });
  it("bounds conversation messages and enforces supported roles",()=>{
    const conversation={id:"conversation",title:"Help",messages:[{id:"message",role:"user",content:"Hi",createdAt:"2026-10-21"}],updatedAt:"2026-10-21"};
    expect(validateRecord("conversations",undefined,conversation).title).toBe("Help");expect(()=>validateRecord("conversations",undefined,{...conversation,messages:[{...conversation.messages[0],role:"system"}]})).toThrow();
  });
});
