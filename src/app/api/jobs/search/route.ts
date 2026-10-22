import { requireUser, HttpError, apiError, assertSameOrigin } from "@/lib/server/auth";
import { getIntegrationSecret } from "@/lib/server/integrations";
import { discoverJobs } from "@/lib/job-discovery";
import type { CompanyFeed } from "@/lib/jobs";

export const runtime = "nodejs";
export const maxDuration = 60;
export async function POST(request: Request) {
  try {
    await assertSameOrigin(request);
    const user = await requireUser();
    if (Number(request.headers.get("content-length") || 0) > 20_000) return Response.json({ error: "Search request too large." }, { status: 413 });
    const rawBody = await request.text();
    if (rawBody.length > 80_000) return Response.json({error:"Request too large."},{status:413});
    const body = JSON.parse(rawBody);
    if (!body || typeof body !== "object" || Array.isArray(body)) return Response.json({error:"Invalid request."},{status:400});
    if (body.query !== undefined && (typeof body.query !== "string" || body.query.length > 500)) return Response.json({ error: "Search must be under 500 characters." }, { status: 400 });
    const companies: CompanyFeed[] = Array.isArray(body.companies) ? body.companies.slice(0, 12).filter((item: unknown): item is CompanyFeed => {
      if (!item || typeof item !== "object") return false;
      const c = item as CompanyFeed;
      return typeof c.name === "string" && c.name.length <= 150 && typeof c.slug === "string" && /^[a-zA-Z0-9_-]{1,80}$/.test(c.slug) && ["greenhouse", "lever"].includes(c.provider);
    }) : [];
    const integration = await getIntegrationSecret(user.id, "tavily");
    return Response.json(await discoverJobs({ query: body.query, companies, apiKey: integration?.apiKey }));
  } catch (error) {
    if (error instanceof HttpError) return apiError(error);
    return Response.json({ error: "Search could not complete. Please try again." }, { status: 500 });
  }
}
