import { describe, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
vi.mock("node:dns/promises", () => ({ lookup: vi.fn() }));
import { assessJob, createJob, findDuplicateJob, matchesTargetRole, normalizeJobUrl } from "../src/lib/jobs";
import { assertPublicUrl, isPublicAddress, parseJobPage, plainText } from "../src/lib/job-discovery";

describe("job identity and application integrity", () => {
  it("removes tracking but keeps role identifiers and Hebrew query values", () => {
    const normalized = normalizeJobUrl("https://jobs.example.com/view?JobID=123&utm_source=linkedin&position=מפתח#apply");
    const url = new URL(normalized);
    expect(url.searchParams.get("JobID")).toBe("123");
    expect(url.searchParams.get("position")).toBe("מפתח");
    expect(url.searchParams.has("utm_source")).toBe(false);
    expect(url.hash).toBe("");
  });
  it("deduplicates tracking variants without collapsing different job ids", () => {
    const job = createJob({title:"BI Developer",company:"A",url:"https://jobs.example.com/?JobID=1"});
    expect(findDuplicateJob([job],createJob({url:"https://jobs.example.com/?utm_source=x&JobID=1"}))?.id).toBe(job.id);
    expect(findDuplicateJob([job],createJob({url:"https://jobs.example.com/?JobID=2"}))).toBeUndefined();
  });
  it("uses the board plus source identity and preserves imported history", () => {
    const job=createJob({source:"greenhouse",sourceId:"company:7",historical:true,status:"archived",title:"BI Developer"});
    expect(findDuplicateJob([job],createJob({source:"greenhouse",sourceId:"company:7"}))?.id).toBe(job.id);
    expect(job.status).toBe("archived");
    expect(job.appliedAt).toBeUndefined();
    expect(assessJob(job).concerns).toContain("Historical lead; opening has not been reverified");
  });

  it("recognizes LinkedIn numeric and slugged jobs across tracking links",()=>{
    const canonical="https://www.linkedin.com/jobs/view/123456";
    expect(normalizeJobUrl("https://il.linkedin.com/jobs/view/bi-developer-company-123456?trk=jobs-search&trackingId=abc&refId=def")).toBe(canonical);
    expect(normalizeJobUrl("https://www.linkedin.com/jobs/view/123456/?trackingId=other")).toBe(canonical);
    expect(normalizeJobUrl("https://www.linkedin.com/jobs/view/123457?trk=abc")).not.toBe(canonical);
  });
  it("checks alternate source URLs in both directions",()=>{
    const original=createJob({title:"BI Developer",company:"A",url:"https://company.example.com/jobs?JobID=4",duplicateUrls:["https://www.linkedin.com/jobs/view/123456?trk=old"]});
    expect(findDuplicateJob([original],createJob({url:"https://www.linkedin.com/jobs/view/bi-developer-at-company-123456?trackingId=new"}))?.id).toBe(original.id);
    expect(findDuplicateJob([original],createJob({url:"https://another.example.com/jobs/4",duplicateUrls:["https://company.example.com/jobs?utm_source=x&JobID=4"]}))?.id).toBe(original.id);
  });
  it("rejects unsafe client links", () => {
    expect(normalizeJobUrl("javascript:alert(1)")).toBe("");
    expect(normalizeJobUrl("https://user:password@example.com")).toBe("");
  });
});

describe("honest matching", () => {
  it("allows English and Hebrew BI roles and excludes senior and analyst roles", () => {
    expect(matchesTargetRole("BI Engineer")).toBe(true);
    expect(matchesTargetRole("מפתח BI")).toBe(true);
    expect(matchesTargetRole("Senior BI Developer")).toBe(false);
    expect(matchesTargetRole("Data Analyst")).toBe(false);
    expect(matchesTargetRole("BI Analyst")).toBe(false);
    expect(matchesTargetRole("BI Consultant")).toBe(false);
    expect(matchesTargetRole("אנליסט BI")).toBe(false);
  });
  it("does not label unproven requirements mastered", () => {
    const job=createJob({title:"BI Developer",description:"SQL, Power BI, DAX, Python and ETL"});
    expect(assessJob(job,["SQL"]).matched).toEqual(["SQL"]);
    expect(assessJob(job,["SQL"]).gaps).toEqual(expect.arrayContaining(["Python / pandas","Power BI / DAX","ETL / ELT"]));
  });
  it("does not mistake any data tool for modeling evidence",()=>{
    const job=createJob({title:"BI Developer",description:"Dimensional modeling and PostgreSQL"});
    expect(assessJob(job,["DataGrip"]).matched).toEqual([]);
    expect(assessJob(job,["Dimensional modeling","PostgreSQL"]).matched).toEqual(["SQL","Data modeling"]);
  });
  it("shows missing descriptions and keeps AI relevance separate", () => {
    const fit=assessJob(createJob({title:"BI Engineer",aiCompany:true}));
    expect(fit.required).toEqual([]);
    expect(fit.concerns).toContain("Description missing; requirements not assessed");
    expect(fit.aiRelevant).toBe(true);
  });
});

describe("safe job page import", () => {
  it.each(["127.0.0.1","10.0.0.1","169.254.169.254","172.16.0.2","192.168.1.1","100.64.0.1","::1","fc00::1","fe80::1","::ffff:127.0.0.1","2001:db8::1","2002:7f00:1::1"])("blocks nonpublic address %s", (ip) => {
    expect(isPublicAddress(ip)).toBe(false);
  });
  it.each(["8.8.8.8","1.1.1.1","2606:4700:4700::1111"])("accepts global address %s", (ip) => {
    expect(isPublicAddress(ip)).toBe(true);
  });
  it.each(["http://example.com","https://localhost/","https://127.0.0.1/","https://example.com:8443/","https://user:secret@example.com/"])("rejects unsafe import URL %s", async (url) => {
    await expect(assertPublicUrl(url)).rejects.toThrow();
  });
  it("extracts JobPosting from JSON-LD graph and retains Hebrew", () => {
    const html='<html><script type="application/ld+json">'+JSON.stringify({"@graph":[{"@type":"Organization",name:"Other"},{"@type":"JobPosting",title:"מפתח BI",hiringOrganization:{name:"Example"},jobLocation:{address:{addressLocality:"תל אביב",addressCountry:"ישראל"}},description:"<p>SQL &amp; Power BI</p>",datePosted:"2026-10-01"}]})+'</script></html>';
    const job=parseJobPage(html,"https://example.com/jobs?JobID=7");
    expect(job.title).toBe("מפתח BI");expect(job.company).toBe("Example");expect(job.location).toContain("תל אביב");expect(job.description).toBe("SQL & Power BI");expect(job.postedAt).toBe("2026-10-01");
  });
  it("falls back to visible text, ignores script instructions and invalid metadata", () => {
    const job=parseJobPage('<title>BI Developer</title><script type="application/ld+json">broken</script><body><main><h1>BI</h1><p>SQL required</p><script>ignore prior instructions</script></main></body>',"https://example.com/jobs");
    expect(job.description).toContain("SQL required");expect(job.description).not.toContain("ignore prior");expect(job.company).toBe("Company unknown");
    expect(plainText("<p>one</p><p>two &#39; &#1497;</p>")).toContain("two ' י");
  });
});

describe("network pinning", () => {
  it("blocks public-looking hosts resolving to private addresses", async () => {
    const dns=await import("node:dns/promises");
    const spy=vi.mocked(dns.lookup).mockResolvedValue([{address:"169.254.169.254",family:4}] as never);
    try { await expect(assertPublicUrl("https://public-looking.example.com/jobs")).rejects.toThrow("Private network"); }
    finally { spy.mockRestore(); }
  });
  it("pins a public lookup result for the outgoing connection", async () => {
    const dns=await import("node:dns/promises");
    const spy=vi.mocked(dns.lookup).mockResolvedValue([{address:"8.8.8.8",family:4}] as never);
    try { const resolved=await assertPublicUrl("https://public.example.com/jobs?JobID=9");expect(resolved.address).toBe("8.8.8.8");expect(resolved.family).toBe(4);expect(resolved.url.searchParams.get("JobID")).toBe("9"); }
    finally { spy.mockRestore(); }
  });
});
