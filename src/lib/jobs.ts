import type { Job, ApplicationStage } from "@/lib/types";

export const JOB_STAGES: ApplicationStage[] = ["discovered", "saved", "preparing", "applied", "interviewing", "offer", "rejected", "withdrawn", "archived"];
export type CompanyFeed = { name: string; provider: "greenhouse" | "lever"; slug: string; aiCompany?: boolean };
export const DEFAULT_COMPANY_FEEDS: CompanyFeed[] = [];

/** Remove tracking only. Application identifiers such as JobID and gh_jid stay intact. */
export function normalizeJobUrl(value: string): string {
  try {
    const url = new URL(value);
    if (!/^https?:$/.test(url.protocol) || url.username || url.password) return "";
    url.hash = "";
    if (/(^|\.)linkedin\.com$/i.test(url.hostname)) {
      const jobId=url.pathname.match(/^\/jobs\/view\/(?:[^/]*-)?(\d+)\/?$/)?.[1];
      if(jobId){url.hostname="www.linkedin.com";url.pathname=`/jobs/view/${jobId}`;url.search="";return url.toString();}
    }
    for (const key of [...url.searchParams.keys()]) {
      if (/^(utm_.+|fbclid|gclid|mc_cid|mc_eid|referrer)$/i.test(key)) url.searchParams.delete(key);
    }
    url.searchParams.sort();
    url.pathname = url.pathname.replace(/\/$/, "") || "/";
    return url.toString();
  } catch { return ""; }
}

export function jobIdentity(job: Pick<Job, "url" | "source" | "sourceId" | "title" | "company">): string {
  if (job.sourceId) return `${job.source.toLowerCase()}:${job.sourceId}`;
  const url = normalizeJobUrl(job.url || "");
  return url || `${job.title.trim().toLowerCase()}::${job.company.trim().toLowerCase()}`;
}

export function findDuplicateJob(jobs: Job[], candidate: Pick<Job, "url" | "source" | "sourceId" | "title" | "company"> & {duplicateUrls?:string[]}): Job | undefined {
  const identity = jobIdentity(candidate);
  const candidateUrls = new Set([candidate.url,...(candidate.duplicateUrls||[])].map(normalizeJobUrl).filter(Boolean));
  return jobs.find((job) => jobIdentity(job) === identity || [job.url,...job.duplicateUrls].some((url)=>candidateUrls.has(normalizeJobUrl(url))));
}

export const SKILL_PATTERNS: { name: string; pattern: RegExp; track: string }[] = [
  { name: "SQL", pattern: /\bSQL\b|PostgreSQL|T-SQL|SQL Server/i, track: "sql" },
  { name: "Data modeling", pattern: /dimensional|data model|star schema|מחסן נתונים|מידול/i, track: "modeling" },
  { name: "ETL / ELT", pattern: /\bETL\b|\bELT\b|SSIS|data pipeline|dbt|תהליכי טעינה/i, track: "etl" },
  { name: "Power BI / DAX", pattern: /Power\s?BI|\bDAX\b/i, track: "powerbi" },
  { name: "Excel / Power Query", pattern: /Excel|Power Query|\bM language\b/i, track: "excel" },
  { name: "Qlik Sense", pattern: /Qlik|קליק/i, track: "qlik" },
  { name: "Python / pandas", pattern: /Python|pandas|numpy/i, track: "python" },
  { name: "Metrics & visualization", pattern: /KPI|visualization|dashboard|statistics|מדדים|דשבורד/i, track: "metrics" },
  { name: "Git & AI tools", pattern: /\bGit\b|GitHub|copilot|LLM|generative AI|AI-assisted|agentic/i, track: "git-ai" },
  { name: "Stakeholder communication", pattern: /stakeholder|business requirements|communication|דרישות עסקיות|אפיון/i, track: "communication" },
];

export function extractJobSkills(text: string): string[] {
  return SKILL_PATTERNS.filter(({ pattern }) => pattern.test(text)).map(({ name }) => name);
}

export function roleConcerns(title: string): string[] {
  const concerns: string[] = [];
  if (/\banalyst\b|אנליסט|אנליסטית/i.test(title) && !/developer|engineer|מפתח/i.test(title)) concerns.push("Analyst role outside your current target");
  if (/\bsenior\b|\blead\b|\bprincipal\b|\bstaff\b|\bhead\b|\bmanager\b|בכיר|ראש צוות|מנהל/i.test(title)) concerns.push("Seniority above junior / mid target");
  if (!/\bBI\b|business intelligence|intelligence developer|מפתח.?\s?BI|בינה עסקית/i.test(title) || !/developer|engineer|מפתח|פיתוח|מהנדס/i.test(title)) concerns.push("Confirm this is a BI development / engineering role");
  return concerns;
}

export function matchesTargetRole(title: string): boolean { return roleConcerns(title).length === 0; }

export function assessJob(job: Job, demonstratedSkills: string[] = []) {
  const text = `${job.title} ${job.description || ""}`;
  const required = extractJobSkills(text);
  const matched = required.filter((skill) => {
    const rule=SKILL_PATTERNS.find((item)=>item.name===skill);
    return !!rule && demonstratedSkills.some((evidence)=>rule.pattern.test(evidence));
  });
  const gaps = required.filter((skill) => !matched.includes(skill));
  const concerns = roleConcerns(job.title);
  if (!job.description?.trim()) concerns.push("Description missing; requirements not assessed");
  if (job.historical) concerns.push("Historical lead; opening has not been reverified");
  const aiRelevant = job.aiCompany === true || /artificial intelligence|\bLLM\b|generative AI|machine learning/i.test(job.description || "");
  const score = Math.max(0, Math.min(100, 45 + matched.length * 7 + (aiRelevant ? 8 : 0) - concerns.length * 18));
  return { required, matched, gaps, concerns, score, aiRelevant };
}

export function formatJobDate(value?: string): string {
  if (!value || Number.isNaN(new Date(value).getTime())) return "Date unknown";
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric" }).format(new Date(value));
}

export function scoreJob(job: Job, demonstratedSkills: string[] = []): Job {
  const fit = assessJob(job, demonstratedSkills);
  return { ...job, canonicalUrl: normalizeJobUrl(job.url), skills: fit.required, fitScore: fit.score, fitReasons: [
    ...fit.matched.map((skill) => `Evidence: ${skill}`),
    ...(fit.aiRelevant ? ["AI relevance indicated by company flag or job description"] : []),
    ...fit.concerns,
  ], gaps: fit.gaps };
}

export function createJob(input: Partial<Job>): Job {
  const now = new Date().toISOString();
  const job: Job = {
    id: crypto.randomUUID(), title: "Untitled role", company: "Company unknown", location: "Location unknown",
    url: "", canonicalUrl: "", description: "", source: "manual", duplicateUrls: [],
    capturedAt: now, historical: false, skills: [], status: "discovered", fitScore: 0, fitReasons: [], gaps: [], notes: "",
    ...input,
  };
  return scoreJob(job);
}
