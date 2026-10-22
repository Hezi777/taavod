import {spawnSync} from 'node:child_process';import {readFile,writeFile} from 'node:fs/promises';import {randomBytes} from 'node:crypto';import {createClient} from '@supabase/supabase-js';
const empty=process.argv.includes('--empty');
const result=spawnSync('supabase',['status','--output','json'],{encoding:'utf8',maxBuffer:1024*1024});
if(result.status!==0){console.error('Start the local database with pnpm services:start, then retry.');process.exit(1);}
const status=JSON.parse(result.stdout);const current={};try{for(const line of (await readFile('.env.local','utf8')).split('\n')){const match=line.match(/^([A-Z_]+)=(.*)$/);if(match)current[match[1]]=match[2].replace(/^"|"$/g,'');}}catch{}
const values={NEXT_PUBLIC_SUPABASE_URL:status.API_URL,NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:status.PUBLISHABLE_KEY||status.ANON_KEY,SUPABASE_SECRET_KEY:status.SECRET_KEY||status.SERVICE_ROLE_KEY,OWNER_EMAIL:process.env.OWNER_EMAIL||current.OWNER_EMAIL||'henzri5000@gmail.com',INTEGRATION_ENCRYPTION_KEY:current.INTEGRATION_ENCRYPTION_KEY||randomBytes(32).toString('base64'),NEXT_PUBLIC_LOCAL_INBOX_URL:status.MAILPIT_URL||status.INBUCKET_URL,MULTI_USER_ENABLED:'false',LOCAL_DEV_MODE:'0'};
if(!values.NEXT_PUBLIC_SUPABASE_URL||!values.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||!values.SUPABASE_SECRET_KEY)throw new Error('Required local Supabase credentials were not available.');
await writeFile('.env.local',Object.entries(values).map(([key,value])=>`${key}=${value}`).join('\n')+'\n',{mode:0o600});
console.log('Local environment configured. Credentials remain private.');
if(empty){
 const admin=createClient(values.NEXT_PUBLIC_SUPABASE_URL,values.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
 let owner=false;
 for(let page=1;;page++){const {data,error}=await admin.auth.admin.listUsers({page,perPage:1000});if(error)throw new Error('Could not inspect local owners.');if(data.users.some(user=>user.email?.toLowerCase()===values.OWNER_EMAIL.toLowerCase())){owner=true;break;}if(data.users.length<1000)break;}
 if(!owner){const {error}=await admin.auth.admin.createUser({email:values.OWNER_EMAIL,email_confirm:true});if(error)throw new Error('Could not create the local owner.');}
 console.log('Owner ready. Sign in to begin onboarding. No personal records were imported.');
}else{
 const imported=spawnSync('pnpm',['import:career','--supabase'],{stdio:'inherit',env:{...process.env,...values}});if(imported.status!==0)process.exit(imported.status||1);
}
console.log('Open http://127.0.0.1:3100 and sign in with the owner email. Sign-in links arrive in the local inbox.');
