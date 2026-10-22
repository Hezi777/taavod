import { beforeEach, describe, expect, it, vi } from "vitest";
const mock=vi.hoisted(()=>({user:vi.fn(),origin:vi.fn(),records:vi.fn(),save:vi.fn(),remove:vi.fn(),download:vi.fn(),upload:vi.fn(),removeStorage:vi.fn()}));
vi.mock("server-only",()=>({}));
vi.mock("@/lib/server/auth",async(importOriginal)=>({...await importOriginal<typeof import("../src/lib/server/auth")>(),requireUser:mock.user,assertSameOrigin:mock.origin,sessionClient:async()=>({storage:{from:()=>({download:mock.download,upload:mock.upload,remove:mock.removeStorage})}})}));
vi.mock("@/lib/server/config",()=>({localMode:()=>false}));
vi.mock("@/lib/server/records",()=>({listRecords:mock.records,saveRecord:mock.save,deleteRecord:mock.remove,localRoot:()=>"/not-used-in-cloud-test"}));
import { GET as getFiles, POST as uploadFile } from "../src/app/api/files/route";
import { GET as getFile, DELETE as deleteFile } from "../src/app/api/files/[id]/route";
import { HttpError } from "../src/lib/server/auth";
const context={params:Promise.resolve({id:"file-one"})};

describe("private evidence API boundary",()=>{
  beforeEach(()=>{vi.clearAllMocks();mock.user.mockResolvedValue({id:"owner",email:"owner@example.com"});mock.origin.mockResolvedValue(undefined);mock.records.mockResolvedValue([]);mock.download.mockResolvedValue({data:new Blob(["private content"]),error:null});mock.upload.mockResolvedValue({error:null});mock.save.mockResolvedValue(undefined);mock.removeStorage.mockResolvedValue({error:null});mock.remove.mockResolvedValue(undefined)});
  it("requires authentication for listing, download and deletion",async()=>{
    mock.user.mockRejectedValue(new HttpError(401,"Sign in to continue."));expect((await getFiles()).status).toBe(401);expect((await getFile(new Request("https://career.example.com/api/files/file-one"),context)).status).toBe(401);expect((await deleteFile(new Request("https://career.example.com/api/files/file-one",{method:"DELETE"}),context)).status).toBe(401);expect(mock.records).not.toHaveBeenCalled();expect(mock.download).not.toHaveBeenCalled();
  });
  it("returns 404 for another user's or nonexistent file without touching storage",async()=>{
    const response=await getFile(new Request("https://career.example.com/api/files/file-one"),context);expect(response.status).toBe(404);expect(mock.records).toHaveBeenCalledWith("owner");expect(mock.download).not.toHaveBeenCalled();
  });
  it("downloads an owned file as a private attachment without public URLs",async()=>{
    mock.records.mockResolvedValue([{kind:"files",id:"file-one",payload:{id:"file-one",path:"owner/file-one.pdf",name:"CV.pdf"}}]);
    const response=await getFile(new Request("https://career.example.com/api/files/file-one"),context);expect(response.status).toBe(200);expect(await response.text()).toBe("private content");expect(response.headers.get("content-disposition")).toContain("attachment");expect(response.headers.get("cache-control")).toContain("private, no-store");expect(response.headers.get("x-content-type-options")).toBe("nosniff");expect(mock.download).toHaveBeenCalledWith("owner/file-one.pdf");
  });
  it("rejects cross-origin file deletion before reading records",async()=>{
    mock.origin.mockRejectedValue(new HttpError(403,"Cross-origin request rejected."));expect((await deleteFile(new Request("https://career.example.com/api/files/file-one",{method:"DELETE"}),context)).status).toBe(403);expect(mock.records).not.toHaveBeenCalled();expect(mock.removeStorage).not.toHaveBeenCalled();
  });
  it("rejects unsupported uploads before storing anything",async()=>{
    const form=new FormData();form.set("file",new File(["not allowed"],"executable.html",{type:"text/html"}));form.set("kind","cv");
    const response=await uploadFile(new Request("https://career.example.com/api/files",{method:"POST",body:form}));expect(response.status).toBe(400);expect(mock.upload).not.toHaveBeenCalled();expect(mock.save).not.toHaveBeenCalled();
  });
});
