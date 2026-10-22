import {requireUser,apiError} from '@/lib/server/auth';import {integrationMetadata} from '@/lib/server/integrations';
export async function GET(){try{const user=await requireUser();return Response.json({integrations:await integrationMetadata(user.id)},{headers:{'Cache-Control':'private, no-store'}});}catch(error){return apiError(error);}}
