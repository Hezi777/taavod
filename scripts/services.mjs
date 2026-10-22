import {spawnSync} from 'node:child_process';
const action=process.argv[2]||'status';const network='career-helper-local';
function run(command,args){return spawnSync(command,args,{encoding:'utf8',maxBuffer:20*1024*1024});}
function fail(message){console.error(message);process.exit(1);}
if(!['start','stop','status'].includes(action))fail('Use start, stop or status.');
if(action==='start'){
 if(run('docker',['info','--format','{{.ServerVersion}}']).status!==0){console.log('Starting OrbStack…');const orb=run('orbctl',['start']);if(orb.status!==0&&run('docker',['info','--format','{{.ServerVersion}}']).status!==0)fail('Start OrbStack or another Docker runtime, then retry.');}
 const inspected=run('docker',['network','inspect',network]);
 if(inspected.status!==0){if(run('docker',['network','create','-o','com.docker.network.bridge.host_binding_ipv4=127.0.0.1',network]).status!==0)fail('Could not create the private Docker network.');}
 else{const data=JSON.parse(inspected.stdout);if(data[0]?.Options?.['com.docker.network.bridge.host_binding_ipv4']!=='127.0.0.1')fail('This Docker network is not restricted to loopback. Use a dedicated loopback network before continuing.');}
 console.log('Starting the local Supabase services. First start may download container images…');
 const result=run('supabase',['start','--network-id',network]);if(result.status!==0)fail('Supabase could not start. Check Docker health and available service ports; credentials were not printed.');
}
if(action==='stop'){const result=run('supabase',['stop']);if(result.status!==0)fail('Could not stop this Supabase stack.');console.log('Career Helper services stopped. Persistent volumes retained.');process.exit(0);}
const status=run('supabase',['status','--output','json']);if(status.status!==0)fail('Local Supabase is not running. Use pnpm services:start.');
const data=JSON.parse(status.stdout);console.log('Career Helper local services are running.');for(const [name,key] of [['API','API_URL'],['Studio','STUDIO_URL'],['Sign-in inbox','MAILPIT_URL']])console.log(`${name}: ${data[key]||'unavailable'}`);
