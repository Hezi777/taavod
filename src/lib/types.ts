export type ApplicationStage = "discovered" | "saved" | "preparing" | "applied" | "interviewing" | "offer" | "rejected" | "withdrawn" | "archived";
export type Company = { id: string; name: string; url?: string; aiCompany?: boolean; feedType?: "greenhouse" | "lever"; feedSlug?: string };
export type Profile = {
  id: string; name: string; headline: string; email: string; location: string;
  targetRoles: string[]; excludedRoles: string[]; targetDate: string; weeklyHours: number;
  preferredIndustry: string; experience: string; bio: string; linkedin: string; github: string; portfolio: string;
  toolAccess: string[]; skillConfidence: Record<string, number>; onboardingComplete: boolean;
  watchlist: Company[]; notes: string; sources: {label: string; url?: string; capturedAt: string; note?: string}[];
};
export type Job = {
  id: string; title: string; company: string; location: string; url: string; canonicalUrl: string;
  description: string; source: string; sourceId?: string; duplicateUrls: string[];
  capturedAt: string; postedAt?: string; verifiedAt?: string; historical: boolean;
  skills: string[]; requiredYears?: number; seniority?: string; workModel?: string;
  aiCompany?: boolean; aiEvidence?: string; status: ApplicationStage; fitScore: number;
  fitReasons: string[]; gaps: string[]; notes: string; followUpDate?: string; appliedAt?: string;
  raw?: Record<string, unknown>;
};
export type PortfolioProject = {
  id: string; name: string; category: string; status: "active" | "beta" | "published" | "archived" | "secondary";
  summary: string; description: string; skills: string[]; repoUrl?: string; demoUrl?: string;
  evidence: string[]; caveat?: string; nextSteps: {id: string; title: string; done: boolean}[];
  interviewStory: string; notes: string; updatedAt: string;
};
export type Attempt = {
  id: string; exerciseId: string; skillId: string; answer: string; passed: boolean | null;
  feedback: string; hintsUsed: number; createdAt: string; mode: "practice" | "assessment";
  selfReported?: boolean;
};
export type PlanTask = {
  id: string; title: string; description?: string; skillId?: string; exerciseId?: string;
  href?: string; minutes: number; done: boolean; dueDate?: string;
  type: "practice" | "review" | "project" | "career" | "interview"; completedAt?: string; weekOf?: string;
};
export type Message = { id: string; role: "user" | "assistant"; content: string; createdAt: string };
export type Conversation = {id: string; title: string; messages: Message[]; updatedAt: string; context?: {type: string; id: string}};
export type Integration = {provider: "anthropic" | "groq" | "tavily"; configured: boolean; model?: string; updatedAt?: string};
export type CareerState = {profile: Profile; jobs: Job[]; projects: PortfolioProject[]; attempts: Attempt[]; tasks: PlanTask[]; conversations: Conversation[]; integrations: Integration[]};
export type EvidenceFile = {id: string; name: string; kind: "cv" | "project" | "assignment"; path: string; createdAt: string; notes: string};
