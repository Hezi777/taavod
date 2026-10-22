import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { readFile } from "node:fs/promises";
import { randomBytes } from "node:crypto";
import { PGlite } from "@electric-sql/pglite";
vi.mock("server-only", () => ({}));
import { encryptSecret, decryptSecret } from "../src/lib/server/integrations";
import { localMode, ownerAllowed } from "../src/lib/server/config";

const A="11111111-1111-4111-8111-111111111111", B="22222222-2222-4222-8222-222222222222";

describe("credential encryption", () => {
  const previous=process.env.INTEGRATION_ENCRYPTION_KEY;
  beforeAll(()=>{process.env.INTEGRATION_ENCRYPTION_KEY=randomBytes(32).toString("base64")});
  afterAll(()=>{if(previous===undefined)delete process.env.INTEGRATION_ENCRYPTION_KEY;else process.env.INTEGRATION_ENCRYPTION_KEY=previous});
  it("round trips secrets with a random nonce and no plaintext",()=>{
    const one=encryptSecret("test-private-key"),two=encryptSecret("test-private-key");
    expect(one).not.toBe(two);expect(one).not.toContain("test-private-key");expect(decryptSecret(one)).toBe("test-private-key");
  });
  it("rejects ciphertext modification",()=>{
    const parts=encryptSecret("private-key").split(".");
    const encrypted=Buffer.from(parts[2],"base64");encrypted[0]^=1;parts[2]=encrypted.toString("base64");
    expect(()=>decryptSecret(parts.join("."))).toThrow();
  });
  it("refuses a missing or wrong encryption key",()=>{
    const key=process.env.INTEGRATION_ENCRYPTION_KEY;const encrypted=encryptSecret("private-key");
    try { delete process.env.INTEGRATION_ENCRYPTION_KEY;expect(()=>encryptSecret("private-key")).toThrow("not configured");process.env.INTEGRATION_ENCRYPTION_KEY=randomBytes(32).toString("base64");expect(()=>decryptSecret(encrypted)).toThrow(); }
    finally {process.env.INTEGRATION_ENCRYPTION_KEY=key}
  });
});

describe("deployment isolation defaults",()=>{
  it("never enables loopback bypass in production or Vercel",()=>{
    const prior={node:process.env.NODE_ENV,local:process.env.LOCAL_DEV_MODE,vercel:process.env.VERCEL};
    try {process.env.LOCAL_DEV_MODE="1";vi.stubEnv("NODE_ENV","production");expect(localMode()).toBe(false);vi.stubEnv("NODE_ENV","development");process.env.VERCEL="1";expect(localMode()).toBe(false);}
    finally {vi.unstubAllEnvs();if(prior.node!==undefined)vi.stubEnv("NODE_ENV",prior.node);if(prior.local===undefined)delete process.env.LOCAL_DEV_MODE;else process.env.LOCAL_DEV_MODE=prior.local;if(prior.vercel===undefined)delete process.env.VERCEL;else process.env.VERCEL=prior.vercel;}
  });
  it("defaults to owner-only access and requires explicit multiuser opt-in",()=>{
    const owner=process.env.OWNER_EMAIL,multi=process.env.MULTI_USER_ENABLED;
    try {process.env.OWNER_EMAIL="owner@example.com";delete process.env.MULTI_USER_ENABLED;expect(ownerAllowed("Owner@example.com")).toBe(true);expect(ownerAllowed("other@example.com")).toBe(false);expect(ownerAllowed(undefined)).toBe(false);process.env.MULTI_USER_ENABLED="true";expect(ownerAllowed("other@example.com")).toBe(true);}
    finally {if(owner===undefined)delete process.env.OWNER_EMAIL;else process.env.OWNER_EMAIL=owner;if(multi===undefined)delete process.env.MULTI_USER_ENABLED;else process.env.MULTI_USER_ENABLED=multi;}
  });
});

describe("actual migration enforces private records, files and secrets",()=>{
  let db:PGlite;
  beforeAll(async()=>{
    db=new PGlite();
    await db.exec(`
      create role anon; create role authenticated; create role service_role bypassrls;
      create schema auth; create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
      create schema storage;
      create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint);
      create table storage.objects(id text primary key,bucket_id text,name text);
      alter table storage.objects enable row level security;
      create function storage.foldername(name text) returns text[] language sql immutable as $$select (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1]$$;
      grant usage on schema public,auth,storage to authenticated,anon,service_role;
      grant select,insert,update,delete on storage.objects to authenticated;
      insert into auth.users values ('${A}'),('${B}');
    `);
    const migration=await readFile(new URL("../supabase/migrations/20261021181401_career_workspace.sql",import.meta.url),"utf8");
    await db.exec(migration);
    await db.query("insert into career_records(user_id,kind,id,payload) values ($1,'jobs','a',$3),($2,'jobs','b',$4)",[A,B,JSON.stringify({id:"a",title:"Owner role"}),JSON.stringify({id:"b",title:"Other role"})]);
    await db.query("insert into integration_secrets(user_id,provider,ciphertext) values ($1,'anthropic','encrypted-owner-key'),($2,'anthropic','encrypted-other-key')",[A,B]);
    await db.query("insert into storage.objects(id,bucket_id,name) values ('a','career-evidence',$1),('b','career-evidence',$2)",[`${A}/cv.pdf`,`${B}/cv.pdf`]);
  });
  afterAll(async()=>{await db?.close()});
  async function asUser<T>(id:string,fn:()=>Promise<T>):Promise<T>{await db.exec("set role authenticated");await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);try{return await fn()}finally{await db.exec("reset role")}}
  it("shows each authenticated user only their own records",async()=>{
    const a=await asUser(A,()=>db.query<{id:string}>("select id from career_records"));expect(a.rows.map(r=>r.id)).toEqual(["a"]);
    const b=await asUser(B,()=>db.query<{id:string}>("select id from career_records"));expect(b.rows.map(r=>r.id)).toEqual(["b"]);
  });
  it("blocks creating or moving records to a different owner",async()=>{
    await asUser(A,async()=>{await expect(db.query("insert into career_records(user_id,kind,id,payload) values ($1,'jobs','forged','{}')",[B])).rejects.toThrow(/row.level security/i);await expect(db.query("update career_records set user_id=$1 where id='a'",[B])).rejects.toThrow(/row.level security/i)});
  });
  it("silently prevents updating or deleting another user's rows",async()=>{
    await asUser(A,async()=>{await db.exec("update career_records set payload='{}' where id='b';delete from career_records where id='b';")});
    const b=await asUser(B,()=>db.query<{payload:{title:string}}>("select payload from career_records where id='b'"));expect(b.rows[0].payload.title).toBe("Other role");
  });
  it("the invoker merge function keeps ownership and existing payload fields",async()=>{
    await asUser(A,()=>db.query("select upsert_career_record('jobs','a',$1)",[JSON.stringify({notes:"Saved"})]));
    const a=await asUser(A,()=>db.query<{payload:{title:string;notes:string}}>("select payload from career_records where id='a'"));expect(a.rows[0].payload).toMatchObject({title:"Owner role",notes:"Saved"});
    const b=await asUser(B,()=>db.query<{payload:{notes?:string}}>("select payload from career_records where id='b'"));expect(b.rows[0].payload.notes).toBeUndefined();
  });
  it("authenticated users cannot read or write even their own integration ciphertext",async()=>{
    await asUser(A,async()=>{await expect(db.query("select * from integration_secrets")).rejects.toThrow(/permission denied/i);await expect(db.query("insert into integration_secrets(user_id,provider,ciphertext) values ($1,'groq','fake')",[A])).rejects.toThrow(/permission denied/i)});
  });
  it("anonymous access to records, secrets, and the merge function is denied",async()=>{
    await db.exec("set role anon");try{await expect(db.query("select * from career_records")).rejects.toThrow(/permission denied/i);await expect(db.query("select * from integration_secrets")).rejects.toThrow(/permission denied/i);await expect(db.query("select upsert_career_record('jobs','forged','{}')")).rejects.toThrow(/permission denied/i)}finally{await db.exec("reset role")}
  });
  it("file policies isolate owner folders and reject foreign uploads",async()=>{
    const own=await asUser(A,()=>db.query<{id:string}>("select id from storage.objects"));expect(own.rows.map(r=>r.id)).toEqual(["a"]);
    await asUser(A,()=>expect(db.query("insert into storage.objects(id,bucket_id,name) values ('forged','career-evidence',$1)",[`${B}/upload.pdf`])).rejects.toThrow(/row.level security/i));
    await asUser(A,()=>db.query("delete from storage.objects where id='b'"));
    const b=await asUser(B,()=>db.query<{id:string}>("select id from storage.objects"));expect(b.rows.map(r=>r.id)).toEqual(["b"]);
  });
});
