// One-time local migration. It never writes private data into the source tree.
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {createHash, createDecipheriv} from 'node:crypto';
import path from 'node:path';
import os from 'node:os';

const legacyRoot = path.resolve(process.argv[2] || process.cwd());
const support = path.join(os.homedir(), 'Library/Application Support/Taavod');
const env = Object.fromEntries((await readFile(path.join(legacyRoot, '.env.local'), 'utf8')).split('\n').filter(line => line && !line.startsWith('#')).map(line => {
  const at = line.indexOf('='); return [line.slice(0, at), line.slice(at + 1).replace(/^['"]|['"]$/g, '')];
}));
const base = env.NEXT_PUBLIC_SUPABASE_URL;
const key = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY;
if (!base || !key || !/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(base)) throw new Error('A running local legacy Supabase installation is required.');
async function request(route) {
  const response = await fetch(base + route, {headers: {apikey: key, Authorization: `Bearer ${key}`}, signal: AbortSignal.timeout(30000)});
  if (!response.ok) throw new Error(`Local migration read failed (${response.status}). The original data is unchanged.`);
  return response;
}
let records = [];
for (let offset = 0;; offset += 500) {
  const batch = await (await request(`/rest/v1/career_records?select=kind,id,payload,user_id&order=kind.asc,id.asc&limit=500&offset=${offset}`)).json();
  records.push(...batch); if (batch.length < 500) break;
}
const owners = new Set(records.map(r => r.user_id));
if (owners.size !== 1) throw new Error('Migration expects exactly one local owner. Select an owner explicitly before migrating.');
const userID = [...owners][0];
await mkdir(path.join(support, 'Evidence'), {recursive: true, mode: 0o700});
await mkdir(path.join(support, 'Backups'), {recursive: true, mode: 0o700});
const stamp = new Date().toISOString().replaceAll(':', '-');
await writeFile(path.join(support, 'Backups', `legacy-${stamp}.json`), JSON.stringify(records), {mode: 0o600});
const checksums = [];
for (const record of records.filter(r => r.kind === 'files')) {
  const originalPath = record.payload.path;
  if (!originalPath || typeof originalPath !== 'string') continue;
  const data = Buffer.from(await (await request('/storage/v1/object/career-evidence/' + originalPath.split('/').map(encodeURIComponent).join('/'))).arrayBuffer());
  const file = path.join(support, 'Evidence', record.id + '-' + path.basename(record.payload.name || originalPath));
  await writeFile(file, data, {mode: 0o600});
  checksums.push({id: record.id, bytes: data.length, sha256: createHash('sha256').update(data).digest('hex')});
  record.payload.path = file;
}
const usage = await (await request(`/rest/v1/ai_usage?select=*&user_id=eq.${encodeURIComponent(userID)}`)).json();
for (const item of usage) records.push({kind: 'usage', id: 'legacy-total', payload: item});
const credentials = {};
const rows = await (await request(`/rest/v1/integration_secrets?select=provider,ciphertext,model&user_id=eq.${encodeURIComponent(userID)}`)).json();
for (const row of rows) {
  if (!env.INTEGRATION_ENCRYPTION_KEY) throw new Error('Cannot migrate an existing connection without its legacy encryption key.');
  const [iv, tag, ciphertext] = row.ciphertext.split('.').map(s => Buffer.from(s, 'base64'));
  const decipher = createDecipheriv('aes-256-gcm', Buffer.from(env.INTEGRATION_ENCRYPTION_KEY, 'base64'), iv);
  decipher.setAuthTag(tag);
  credentials[row.provider] = {key: Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString('utf8'), model: row.model || ''};
}
const exported = records.map(({kind, id, payload}) => ({kind, id, payload}));
await writeFile(path.join(support, 'pending-import.json'), JSON.stringify(exported), {mode: 0o600});
if (Object.keys(credentials).length) await writeFile(path.join(support, 'pending-credentials.json'), JSON.stringify(credentials), {mode: 0o600});
const counts = Object.fromEntries([...new Set(exported.map(r => r.kind))].sort().map(kind => [kind, exported.filter(r => r.kind === kind).length]));
await writeFile(path.join(support, 'Backups', `migration-report-${stamp}.json`), JSON.stringify({counts, evidence: checksums, connections: Object.keys(credentials)}, null, 2), {mode: 0o600});
console.log('Private migration prepared:', JSON.stringify(counts), `${checksums.length} evidence files verified; ${Object.keys(credentials).length} connections queued for Keychain.`);
