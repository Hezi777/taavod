import 'server-only';
import {mkdir,readFile,writeFile,rename} from 'node:fs/promises';
import path from 'node:path';
import {localMode} from './config';
import {sessionClient} from './auth';
import type {CareerState, Profile} from '../types';
export type RecordKind = 'profile'|'jobs'|'projects'|'attempts'|'tasks'|'conversations'|'files';
export type StoredRecord = {kind:RecordKind;id:string;payload:Record<string,unknown>};
const locks = new Map<string,Promise<unknown>>();
async function withLock<T>(key:string,fn:()=>Promise<T>):Promise<T>{const prior=locks.get(key)||Promise.resolve(); const current=prior.catch(()=>{}).then(fn);locks.set(key,current);try{return await current;}finally{if(locks.get(key)===current)locks.delete(key);}}
export const localRoot=()=>path.join(process.cwd(),'.local');
async function readLocal(userId:string):Promise<StoredRecord[]> { try{return JSON.parse(await readFile(path.join(localRoot(),`${userId}.json`),'utf8'));}catch(e){if((e as NodeJS.ErrnoException).code==='ENOENT')return [];throw e;} }
export async function listRecords(userId:string) {
  if(localMode())return readLocal(userId);
  const client=await sessionClient();const records:StoredRecord[]=[];const pageSize=500;
  for(let start=0;;start+=pageSize){const {data,error}=await client.from('career_records').select('kind,id,payload').eq('user_id',userId).order('created_at').order('kind').order('id').range(start,start+pageSize-1);if(error)throw error;const page=(data||[]) as StoredRecord[];records.push(...page);if(page.length<pageSize)return records;}

}
export async function getRecord(userId:string,kind:RecordKind,id:string):Promise<StoredRecord|undefined>{
  if(localMode())return (await readLocal(userId)).find(record=>record.kind===kind&&record.id===id);
  const client=await sessionClient();const {data,error}=await client.from('career_records').select('kind,id,payload').eq('user_id',userId).eq('kind',kind).eq('id',id).maybeSingle();if(error)throw error;return data?data as StoredRecord:undefined;
}
export async function saveRecord(userId:string,kind:RecordKind,id:string,patch:Record<string,unknown>){
  if(localMode())return withLock(userId,async()=>{const records=await readLocal(userId);const found=records.find(r=>r.kind===kind&&r.id===id);if(found)found.payload={...found.payload,...patch};else records.push({kind,id,payload:{...patch,id:kind==='profile'?userId:id}});await mkdir(localRoot(),{recursive:true});const file=path.join(localRoot(),`${userId}.json`);await writeFile(`${file}.tmp`,JSON.stringify(records),{mode:0o600});await rename(`${file}.tmp`,file);});
  const client=await sessionClient();const {error}=await client.rpc('upsert_career_record',{record_kind:kind,record_id:id,record_patch:{...patch,id:kind==='profile'?userId:id}});if(error)throw error;
}
export async function deleteRecord(userId:string,kind:RecordKind,id:string){
  if(localMode())return withLock(userId,async()=>{const records=(await readLocal(userId)).filter(r=>r.kind!==kind||r.id!==id);const file=path.join(localRoot(),`${userId}.json`);await writeFile(`${file}.tmp`,JSON.stringify(records),{mode:0o600});await rename(`${file}.tmp`,file);});
  const client=await sessionClient();const {error}=await client.from('career_records').delete().eq('user_id',userId).eq('kind',kind).eq('id',id);if(error)throw error;
}
export function emptyProfile(id:string,email:string):Profile{return {id,name:'',email,headline:'',location:'',targetRoles:['BI Developer','BI Engineer'],excludedRoles:['Data Analyst'],targetDate:'2027-02-15',weeklyHours:4,preferredIndustry:'AI and technology',experience:'',bio:'',linkedin:'',github:'',portfolio:'',toolAccess:[],skillConfidence:{},onboardingComplete:false,watchlist:[],notes:'',sources:[]};}
export function stateFromRecords(records:StoredRecord[],id:string,email:string):CareerState {const values=(kind:RecordKind)=>records.filter(r=>r.kind===kind).map(r=>r.payload);return {profile:(values('profile')[0]||emptyProfile(id,email)) as unknown as CareerState['profile'],jobs:values('jobs') as unknown as CareerState['jobs'],projects:values('projects') as unknown as CareerState['projects'],attempts:values('attempts') as unknown as CareerState['attempts'],tasks:values('tasks') as unknown as CareerState['tasks'],conversations:values('conversations') as unknown as CareerState['conversations'],integrations:[]};}
