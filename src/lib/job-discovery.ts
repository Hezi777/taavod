import "server-only";
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";
import https from "node:https";
import type { Job } from "@/lib/types";
import { createJob, findDuplicateJob, matchesTargetRole, normalizeJobUrl, type CompanyFeed } from "./jobs";

const MAX_BYTES = 2_000_000;
const TIMEOUT = 12_000;

export function isPublicAddress(address: string): boolean {
  const ip = address.toLowerCase().replace(/^\[|\]$/g, "");
  if (isIP(ip) === 4) {
    const [a, b] = ip.split(".").map(Number);
    return !(a === 0 || a === 10 || a === 127 || a >= 224 || (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) || (a === 192 && (b === 168 || b === 0 || b === 2)) ||
      (a === 100 && b >= 64 && b <= 127) || (a === 198 && (b === 18 || b === 19 || b === 51)) || (a === 203 && b === 0));
  }
  // Accept only global unicast IPv6. Reject mapped/translated IPv4, link-local, ULA and multicast.
  return isIP(ip) === 6 && /^[23][0-9a-f]{0,3}:/.test(ip) && !ip.startsWith("2001:db8:") && !ip.startsWith("2001:0:") && !ip.startsWith("2002:");
}

export async function assertPublicUrl(value: string): Promise<{ url: URL; address: string; family: number }> {
  const url = new URL(value);
  if (url.protocol !== "https:" || (url.port && url.port !== "443") || url.username || url.password) throw new Error("Use a public HTTPS job URL without credentials or custom ports.");
  const host = url.hostname.replace(/^\[|\]$/g, "").toLowerCase();
  if ((!isIP(host) && !host.includes(".")) || /(?:^|\.)(localhost|local|internal|test|invalid)$/.test(host)) throw new Error("Private network URLs cannot be imported.");
  const addresses = isIP(host) ? [{ address: host, family: isIP(host) }] : await lookup(host, { all: true, verbatim: true });
  if (!addresses.length || addresses.some(({ address }) => !isPublicAddress(address))) throw new Error("Private network URLs cannot be imported.");
  return { url, ...addresses[0] };
}

/** Pin the validated address to the TLS request so a DNS change cannot bypass URL checks. */
export async function fetchPublicText(value: string, redirects = 0): Promise<{ text: string; url: string; contentType: string }> {
  if (redirects > 4) throw new Error("Too many redirects. Paste the job description instead.");
  const { url, address, family } = await assertPublicUrl(value);
  return new Promise((resolve, reject) => {
    const request = https.request(url, {
      method: "GET", family, headers: { Accept: "text/html,application/json,text/plain", "User-Agent": "CareerHelper/1.0 (personal job capture)", "Accept-Encoding": "identity" },
      lookup: (_hostname, _options, callback) => callback(null, address, family),
    }, (response) => {
      const status = response.statusCode || 500;
      if (status >= 300 && status < 400 && response.headers.location) {
        response.resume();
        fetchPublicText(new URL(response.headers.location, url).href, redirects + 1).then(resolve, reject);
        return;
      }
      if (status < 200 || status >= 300) { response.resume(); reject(new Error(`This page returned ${status}. Paste the description instead.`)); return; }
      const contentType = response.headers["content-type"] || "";
      if (!/text\/(html|plain)|application\/(json|ld\+json)/i.test(contentType)) { response.resume(); reject(new Error("This URL is not a text job page. Paste its description instead.")); return; }
      if (Number(response.headers["content-length"]) > MAX_BYTES) { response.destroy(); reject(new Error("This page is too large. Paste the job description instead.")); return; }
      const chunks: Buffer[] = []; let size = 0;
      response.on("data", (chunk: Buffer) => { size += chunk.length; if (size > MAX_BYTES) { request.destroy(new Error("This page is too large. Paste the description instead.")); } else chunks.push(chunk); });
      response.on("error", reject);
      response.on("end", () => resolve({ text: Buffer.concat(chunks).toString("utf8"), url: url.href, contentType }));
    });
    request.setTimeout(TIMEOUT, () => request.destroy(new Error("This page took too long. Paste the description instead.")));
    const deadline = setTimeout(() => request.destroy(new Error("This page took too long. Paste the description instead.")), TIMEOUT);
    request.on("close", () => clearTimeout(deadline));
    request.on("error", reject); request.end();
  });
}

export function plainText(html: string): string {
  return html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ").replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
    .replace(/<\/(?:p|div|li|h[1-6])>|<br\s*\/?\s*>/gi, "\n").replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'")
    .replace(/&#(\d{1,7});/g, (_, code) => { const n = Number(code); return n <= 0x10ffff ? String.fromCodePoint(n) : ""; })
    .replace(/[ \t]+/g, " ").replace(/\n\s*\n+/g, "\n\n").trim();
}

type JsonRecord = Record<string, unknown>;
const record = (v: unknown): JsonRecord => v && typeof v === "object" && !Array.isArray(v) ? v as JsonRecord : {};
const str = (v: unknown) => typeof v === "string" ? v : "";
function findPosting(value: unknown): JsonRecord | undefined {
  if (Array.isArray(value)) { for (const item of value) { const found = findPosting(item); if (found) return found; } return; }
  const obj = record(value); const type = obj["@type"];
  if (type === "JobPosting" || (Array.isArray(type) && type.includes("JobPosting"))) return obj;
  return obj["@graph"] ? findPosting(obj["@graph"]) : undefined;
}

export function parseJobPage(html: string, url: string): Partial<Job> {
  let posting: JsonRecord | undefined;
  for (const script of html.matchAll(/<script\b[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)) {
    try { posting = findPosting(JSON.parse(script[1])); if (posting) break; } catch { /* Some sites contain invalid unrelated metadata. */ }
  }
  const title = plainText(str(posting?.title) || html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] || "Untitled role");
  const organization = record(posting?.hiringOrganization);
  const locations = Array.isArray(posting?.jobLocation) ? posting.jobLocation : [posting?.jobLocation];
  const location = locations.map((v) => { const l = record(v); const a = record(l.address); return [a.addressLocality, a.addressRegion, a.addressCountry].map(str).filter(Boolean).join(", "); }).filter(Boolean).join(" / ");
  const description = plainText(str(posting?.description) || html.match(/<main\b[^>]*>([\s\S]*?)<\/main>/i)?.[1] || html.match(/<body\b[^>]*>([\s\S]*?)<\/body>/i)?.[1] || html).slice(0, 60_000);
  const postedAt = str(posting?.datePosted);
  return { title, company: str(organization.name) || "Company unknown", location: location || "Location unknown", description, url, canonicalUrl: normalizeJobUrl(url), source: new URL(url).hostname, postedAt: postedAt && !Number.isNaN(Date.parse(postedAt)) ? postedAt : undefined };
}

export async function importJob(input: { url?: string; text?: string }): Promise<{ job: Partial<Job>; warnings: string[] }> {
  const warnings: string[] = [];
  if (input.text?.trim()) {
    const text = input.text.trim().slice(0, 60_000);
    const title = text.split("\n").find((line) => line.trim())?.slice(0, 180) || "Untitled role";
    return { job: createJob({ title, description: text, url: input.url ? normalizeJobUrl(input.url) : "", source: "pasted description" }), warnings: ["Check the title, company and location before saving."] };
  }
  if (!input.url) throw new Error("Add a job URL or paste a description.");
  {
    const page = await fetchPublicText(input.url);
    const parsed = parseJobPage(page.text, page.url);
    if (parsed.company === "Company unknown") warnings.push("Company was not available in structured data; add it below.");
    warnings.push("Review the extracted text. A successful page fetch does not confirm that applications are still open.");
    return { job: createJob({ ...parsed, verifiedAt: new Date().toISOString() }), warnings };
  }
}

export async function discoverJobs(input: { query?: string; companies?: CompanyFeed[]; apiKey?: string }): Promise<{ jobs: Job[]; warnings: string[] }> {
  const jobs: Job[] = []; const warnings: string[] = [];
  const add = (job: Job) => { if (!findDuplicateJob(jobs, job)) jobs.push(job); };
  const tasks: Promise<void>[] = [];
  if (input.apiKey) tasks.push((async () => {
    const query = `${input.query?.trim() || '"BI Developer" OR "BI Engineer" OR "מפתח BI"'} Israel ישראל -"Senior" -"Data Analyst"`;
    const response = await fetch("https://api.tavily.com/search", { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${input.apiKey}` }, body: JSON.stringify({ query, max_results: 20, search_depth: "basic", include_answer: false }), signal: AbortSignal.timeout(TIMEOUT) });
    if (!response.ok) throw new Error("Search provider rejected the request. Check the Tavily connection in Settings.");
    const data = record(await response.json());
    for (const raw of Array.isArray(data.results) ? data.results.slice(0, 20) : []) {
      const item = record(raw); const url = normalizeJobUrl(str(item.url)); if (!url) continue;
      const title = str(item.title); if (!matchesTargetRole(title)) continue;
      add(createJob({ title, description: str(item.content), url, source: "Tavily", location: "Israel relevance from search; confirm on posting", notes: "Search excerpt only. Import the original page for the full requirements. Opening status unverified." }));
    }
  })().catch((error) => { warnings.push(error instanceof Error ? error.message : "Live search failed."); }));
  else warnings.push("Connect Tavily in Settings for web search. Public company feeds work without a search key.");
  for (const company of (input.companies || []).slice(0, 12)) tasks.push((async () => {
    if (!/^[a-zA-Z0-9_-]{1,80}$/.test(company.slug)) throw new Error(`${company.name}: use the board slug, not a URL.`);
    const endpoint = company.provider === "greenhouse" ? `https://boards-api.greenhouse.io/v1/boards/${company.slug}/jobs?content=true` : `https://api.lever.co/v0/postings/${company.slug}?mode=json`;
    const page = await fetchPublicText(endpoint); const data: unknown = JSON.parse(page.text);
    const items = company.provider === "greenhouse" ? record(data).jobs : data;
    for (const raw of Array.isArray(items) ? items : []) {
      const item = record(raw); const categories = record(item.categories);
      const title = str(item.title) || str(item.text); const location = str(record(item.location).name) || str(categories.location);
      if (!matchesTargetRole(title) || !/Israel|ישראל|Tel Aviv|תל אביב|Herzliya|הרצליה|Ramat|רמת|Haifa|חיפה|Petah|פתח|Netanya|נתניה|Jerusalem|ירושלים|Raanana|רעננה|Hod Hasharon|הוד השרון|Kfar Saba|כפר סבא|Rehovot|רחובות|Yokneam|יקנעם|Beer.?Sheva|באר שבע/i.test(location)) continue;
      const url = normalizeJobUrl(str(item.absolute_url) || str(item.hostedUrl)); if (!url) continue;
      const description = plainText(str(item.content) || str(item.descriptionPlain) || str(item.description));
      add(createJob({ title, company: company.name, location, description, url, source: company.provider, sourceId: `${company.slug}:${String(item.id || "")}`, aiCompany: company.aiCompany, aiEvidence: company.aiCompany ? "Marked as AI company in your watchlist" : undefined, verifiedAt: new Date().toISOString(), notes: "Listed in the company's public job feed at capture time. Confirm details before applying." }));
    }
  })().catch(() => { warnings.push(`${company.name}: the public job feed could not be loaded. Check its provider and slug.`); }));
  await Promise.all(tasks);
  jobs.sort((a, b) => Number(b.aiCompany || false) - Number(a.aiCompany || false) || b.fitScore - a.fitScore);
  if (!jobs.length) warnings.push("No matching junior / mid BI development roles were returned. Try another query or add company feeds.");
  return { jobs, warnings };
}
