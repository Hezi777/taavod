import 'server-only';
import {createCipheriv,createDecipheriv,randomBytes} from 'node:crypto';
import {mkdir,readFile,writeFile,rename} from 'node:fs/promises';
import path from 'node:path';
import {localMode} from './config';
import {adminClient} from './admin';
import {localRoot} from './records';
import type {Integration} from '../types';
export type Provider=Integration['provider'];
const mutationLocks = new Map<string,Promise<unknown>>();
async function locked<T>(id:string,fn:()=>Promise<T>):Promise<T>{const prior=mutationLocks.get(id)||Promise.resolve();const operation=prior.catch(()=>{}).then(fn);mutationLocks.set(id,operation);try{return await operation;}finally{if(mutationLocks.get(id)===operation)mutationLocks.delete(id);}}
async function writeRows(userId:string,value:unknown){await mkdir(localRoot(),{recursive:true});const file=path.join(localRoot(),`${userId}-integrations.json`);await writeFile(`${file}.tmp`,JSON.stringify(value),{mode:0o600});await rename(`${file}.tmp`,file);}
function encryptionKey(){const raw=process.env.INTEGRATION_ENCRYPTION_KEY;if(!raw||Buffer.from(raw,'base64').length!==32)throw new Error('Integration encryption is not configured.');return Buffer.from(raw,'base64');}
export function encryptSecret(value:string){const iv=randomBytes(12);const cipher=createCipheriv('aes-256-gcm',encryptionKey(),iv);const encrypted=Buffer.concat([cipher.update(value,'utf8'),cipher.final()]);return [iv.toString('base64'),cipher.getAuthTag().toString('base64'),encrypted.toString('base64')].join('.');}
export function decryptSecret(value:string){const [iv,tag,encrypted]=value.split('.');const cipher=createDecipheriv('aes-256-gcm',encryptionKey(),Buffer.from(iv,'base64'));cipher.setAuthTag(Buffer.from(tag,'base64'));return Buffer.concat([cipher.update(Buffer.from(encrypted,'base64')),cipher.final()]).toString('utf8');}
async function rows(userId:string):Promise<{provider:Provider;ciphertext:string;model?:string;updated_at:string}[]>{if(localMode()){try{return JSON.parse(await readFile(path.join(localRoot(),`${userId}-integrations.json`),'utf8'));}catch(e){if((e as NodeJS.ErrnoException).code==='ENOENT')return [];throw e;}}const {data,error}=await adminClient().from('integration_secrets').select('provider,ciphertext,model,updated_at').eq('user_id',userId);if(error)throw error;return data||[];}
export async function integrationMetadata(userId:string):Promise<Integration[]>{const stored=await rows(userId);return (['anthropic','groq','tavily'] as Provider[]).map(provider=>{const row=stored.find(r=>r.provider===provider);return {provider,configured:Boolean(row),model:row?.model,updatedAt:row?.updated_at};});}
export async function getIntegrationSecret(userId:string,provider:Provider){const row=(await rows(userId)).find(r=>r.provider===provider);return row?{apiKey:decryptSecret(row.ciphertext),model:row.model}:null;}
export async function saveIntegration(userId:string,provider:Provider,apiKey:string,model?:string){const row={provider,ciphertext:encryptSecret(apiKey),model,updated_at:new Date().toISOString()};if(localMode()){await locked(userId,async()=>writeRows(userId,[...(await rows(userId)).filter(r=>r.provider!==provider),row]));}else{const {error}=await adminClient().from('integration_secrets').upsert({user_id:userId,...row},{onConflict:'user_id,provider'});if(error)throw error;}}
export async function removeIntegration(userId:string,provider:Provider){if(localMode()){await locked(userId,async()=>writeRows(userId,(await rows(userId)).filter(r=>r.provider!==provider)));}else{const {error}=await adminClient().from('integration_secrets').delete().eq('user_id',userId).eq('provider',provider);if(error)throw error;}}
