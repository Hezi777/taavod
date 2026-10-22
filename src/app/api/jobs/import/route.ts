import { requireUser, HttpError, apiError, assertSameOrigin } from "@/lib/server/auth";
import { importJob } from "@/lib/job-discovery";

export const runtime = "nodejs";
export const maxDuration = 60;
export async function POST(request: Request) {
  try {
    await assertSameOrigin(request);
    await requireUser();
    if (Number(request.headers.get("content-length") || 0) > 80_000) return Response.json({ error: "Paste a description under 60,000 characters." }, { status: 413 });
    const rawBody = await request.text();
    if (rawBody.length > 80_000) return Response.json({error:"Request too large."},{status:413});
    const body = JSON.parse(rawBody);
    if (!body || typeof body !== "object" || Array.isArray(body)) return Response.json({error:"Invalid request."},{status:400});
    if ((body.url !== undefined && (typeof body.url !== "string" || body.url.length > 3000)) || (body.text !== undefined && (typeof body.text !== "string" || body.text.length > 60_000))) return Response.json({ error: "Invalid URL or description is too long." }, { status: 400 });
    return Response.json(await importJob({ url: body.url, text: body.text }));
  } catch (error) {
    if (error instanceof HttpError) return apiError(error);
    const message = error instanceof Error ? error.message : "Could not import this page. Paste its description instead.";
    // Network internals and request URLs must not leak into responses.
    const safe = /^(Use a public|Private network|This page|This URL|Too many redirects|Add a job)/.test(message);
    return Response.json({ error: safe ? message : "Could not import this page. Paste its description instead." }, { status: 400 });
  }
}
