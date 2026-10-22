import 'server-only';
import { createServerClient } from '@supabase/ssr';
import { cookies, headers } from 'next/headers';
import { cloudConfigured, localMode, ownerAllowed } from './config';
export class HttpError extends Error { constructor(public status: number, message: string) { super(message); } }
export async function sessionClient() {
  const jar = await cookies();
  return createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!, {cookies:{getAll:()=>jar.getAll(),setAll(values){try{values.forEach(({name,value,options})=>jar.set(name,value,options));}catch{ /* Proxy refreshes cookies for server components. */ }}}});
}
export async function requireUser() {
  if (localMode()) {
    const host = (await headers()).get('host')?.split(':')[0];
    if (!host || !['localhost','127.0.0.1','['].includes(host)) throw new HttpError(403,'Local mode only accepts loopback requests.');
    return {id:'local-hen',email:process.env.OWNER_EMAIL || 'local@example.invalid'};
  }
  if (!cloudConfigured()) throw new HttpError(503,'Private storage is not configured yet.');
  const client = await sessionClient();
  const {data:{user},error} = await client.auth.getUser();
  if (error || !user) throw new HttpError(401,'Sign in to continue.');
  if (!ownerAllowed(user.email)) throw new HttpError(403,'This workspace is private.');
  return {id:user.id,email:user.email || ''};
}
export async function assertSameOrigin(request: Request) {
  const origin = request.headers.get('origin');
  const host = request.headers.get('x-forwarded-host') || request.headers.get('host');
  if (origin && new URL(origin).host !== host) throw new HttpError(403,'Cross-origin request rejected.');
}
export function apiError(error: unknown) {
  if (error instanceof HttpError) return Response.json({error:error.message},{status:error.status});
  if(error instanceof SyntaxError)return Response.json({error:'Submit valid JSON.'},{status:400});
  if (error instanceof Error && error.name === 'ZodError') return Response.json({error:'Check the submitted fields.'},{status:400});
  console.error('Career Helper operation failed:', error instanceof Error ? error.name : 'unknown');
  return Response.json({error:'Could not complete this action. Please retry.'},{status:500});
}
