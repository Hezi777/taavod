import {z} from 'zod';
import {requireUser,assertSameOrigin,apiError,HttpError} from '@/lib/server/auth';
import {listRecords,getRecord,saveRecord,stateFromRecords,emptyProfile} from '@/lib/server/records';
import {integrationMetadata} from '@/lib/server/integrations';
import {validateRecord} from '@/lib/validation';
import {localMode,localSupabase} from '@/lib/server/config';
export const dynamic='force-dynamic';
export async function GET(){try{const user=await requireUser();const state=stateFromRecords(await listRecords(user.id),user.id,user.email);state.integrations=await integrationMetadata(user.id);return Response.json({state,mode:localMode()?'local':localSupabase()?'supabase-local':'cloud'},{headers:{'Cache-Control':'private, no-store'}});}catch(error){return apiError(error);}}
const mutation=z.object({kind:z.enum(['profile','jobs','projects','attempts','tasks','conversations']),id:z.string().min(1).max(120),patch:z.record(z.string(),z.unknown())});
async function requestJson(request:Request){
  if(Number(request.headers.get('content-length')||0)>1_000_000)throw new HttpError(413,'This update is too large.');
  const reader=request.body?.getReader();if(!reader)throw new HttpError(400,'Submit a JSON update.');let bytes=0;const chunks:Uint8Array[]=[];
  try{while(true){const {value,done}=await reader.read();if(done)break;bytes+=value.byteLength;if(bytes>1_000_000){await reader.cancel();throw new HttpError(413,'This update is too large.');}chunks.push(value);}}finally{reader.releaseLock();}
  try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw new HttpError(400,'Submit valid JSON.');}
}
export async function POST(request:Request){try{
  await assertSameOrigin(request);const user=await requireUser();const {kind,id,patch}=mutation.parse(await requestJson(request));
  delete patch.user_id;delete patch.userId;delete patch.integrations;
  const recordId=kind==='profile'?'profile':id;const previous=await getRecord(user.id,kind,recordId);
  if(kind==='profile'){patch.id=user.id;patch.email=user.email;}else patch.id=recordId;
  const existing=previous?.payload||(kind==='profile'?emptyProfile(user.id,user.email) as unknown as Record<string,unknown>:undefined);
  const validated=validateRecord(kind,existing,patch);
  // Save only validated patch fields. Keeping the database merge avoids overwriting concurrent edits to other fields.
  const validatedPatch=Object.fromEntries(Object.keys(patch).filter(key=>Object.hasOwn(validated,key)).map(key=>[key,validated[key]]));
  if(!previous)Object.assign(validatedPatch,validated);
  await saveRecord(user.id,kind,recordId,validatedPatch);return Response.json({saved:true});
}catch(error){return apiError(error);}}
