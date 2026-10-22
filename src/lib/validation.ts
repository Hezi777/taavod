import { z } from "zod";

const id = z.string().min(1).max(120);
const text = (max = 500) => z.string().max(max);
const strings = (max = 100, length = 300) => z.array(text(length)).max(max);
const dateText = text(200); // Historical imports include blank and relative publication dates.
const publicUrl = text(4000).refine((value) => {
  if (!value) return true;
  try { const url = new URL(value); return /^https?:$/.test(url.protocol) && !url.username && !url.password; }
  catch { return false; }
}, "Use an http or https URL.");
const destination = text(4000).refine((value) => !value || (value.startsWith("/") && !value.startsWith("//") && !value.includes("\\")) || publicUrl.safeParse(value).success, "Use an internal path or http(s) URL.");

export const profileSchema = z.object({
  id, name: text(200), email: text(320), headline: text(500), location: text(500),
  targetRoles: strings(50), excludedRoles: strings(50), targetDate: z.iso.date(), weeklyHours: z.number().min(1).max(40),
  preferredIndustry: text(1000), experience: text(20_000), bio: text(20_000), linkedin: publicUrl, github: publicUrl, portfolio: publicUrl,
  toolAccess: strings(), skillConfidence: z.record(text(80), z.number().min(0).max(5)).refine((v) => Object.keys(v).length <= 100), onboardingComplete: z.boolean(),
  watchlist: z.array(z.object({ id, name: text(200), url: publicUrl.optional(), aiCompany: z.boolean().optional(), feedType: z.enum(["greenhouse", "lever"]).optional(), feedSlug: text(80).optional() })).max(100),
  notes: text(30_000), sources: z.array(z.object({ label: text(500), url: publicUrl.optional(), capturedAt: dateText, note: text(5000).optional() })).max(200),
});
export const jobSchema = z.object({
  id, title: text(1000), company: text(500), location: text(1000), url: text(4000), canonicalUrl: text(4000),
  description: text(120_000), source: text(300), sourceId: text(500).optional(), duplicateUrls: strings(200,4000), capturedAt: dateText,
  postedAt: dateText.optional(), verifiedAt: dateText.optional(), historical: z.boolean(), skills: strings(200),
  requiredYears: z.number().min(0).max(80).optional(), seniority: text(500).optional(), workModel: text(500).optional(),
  aiCompany: z.boolean().optional(), aiEvidence: text(5000).optional(), status: z.enum(["discovered", "saved", "preparing", "applied", "interviewing", "offer", "rejected", "withdrawn", "archived"]),
  fitScore: z.number().min(0).max(100), fitReasons: strings(100,5000), gaps: strings(100,5000), notes: text(50_000), followUpDate: dateText.optional(), appliedAt: dateText.optional(),
  raw: z.record(text(500),z.unknown()).optional(),
});
export const projectSchema = z.object({
  id, name: text(500), category: text(500), status: z.enum(["active", "beta", "published", "archived", "secondary"]),
  summary: text(10_000), description: text(50_000), skills: strings(200), repoUrl: publicUrl.optional(), demoUrl: publicUrl.optional(),
  evidence: strings(200,10_000), caveat: text(20_000).optional(), nextSteps: z.array(z.object({id,title:text(2000),done:z.boolean()})).max(200),
  interviewStory: text(50_000), notes: text(50_000), updatedAt: dateText,
});
export const attemptSchema = z.object({
  id, exerciseId: id, skillId: id, answer: text(100_000), passed: z.boolean().nullable(), feedback: text(30_000),
  hintsUsed: z.number().int().min(0).max(1000), createdAt: z.iso.datetime(), mode: z.enum(["practice", "assessment"]), selfReported: z.boolean().optional(),
});
export const taskSchema = z.object({
  id, title: text(2000), description: text(20_000).optional(), skillId: id.optional(), exerciseId: id.optional(), href: destination.optional(),
  minutes: z.number().min(0).max(1440), done: z.boolean(), dueDate: dateText.optional(),
  type: z.enum(["practice", "review", "project", "career", "interview"]), completedAt: dateText.optional(), weekOf: dateText.optional(),
});
export const conversationSchema = z.object({
  id, title: text(1000), messages: z.array(z.object({id,role:z.enum(["user","assistant"]),content:text(100_000),createdAt:dateText})).max(500),
  updatedAt: dateText, context: z.object({type:text(100),id}).optional(),
});
export const recordSchemas = { profile: profileSchema, jobs: jobSchema, projects: projectSchema, attempts: attemptSchema, tasks: taskSchema, conversations: conversationSchema };
export type WritableRecordKind = keyof typeof recordSchemas;

/** Validate the complete resulting record so partial edits cannot corrupt existing arrays or nested fields. */
export function validateRecord(kind: WritableRecordKind, existing: Record<string,unknown> | undefined, patch: Record<string,unknown>): Record<string,unknown> {
  return recordSchemas[kind].parse({ ...existing, ...patch });
}
