import {requireUser,apiError} from '@/lib/server/auth';import {readUsage} from '@/lib/server/usage';
export async function GET(){try{const user=await requireUser();return Response.json({usage:await readUsage(user.id)},{headers:{'Cache-Control':'private, no-store'}});}catch(error){return apiError(error);}}
