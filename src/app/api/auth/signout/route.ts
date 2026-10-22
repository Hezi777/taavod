import {assertSameOrigin,sessionClient,apiError} from '@/lib/server/auth';import {localMode} from '@/lib/server/config';
export async function POST(request:Request){try{await assertSameOrigin(request);if(!localMode())await (await sessionClient()).auth.signOut();return Response.json({signedOut:true});}catch(error){return apiError(error);}}
