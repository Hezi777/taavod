import { writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

// Reproducible browser-only sample DB. Never imports into the private app database.
const revision = 'ce6e114236bb828e5ec0dc835f65f1bf1b9179f5';
const base = `https://raw.githubusercontent.com/devrimgunduz/pagila/${revision}/`;
const tables = ['actor','address','category','city','country','customer','film','film_actor','film_category','inventory','language','payment','rental','staff','store'];
const source = async name => {
  const response = await fetch(base + name);
  if (!response.ok) throw new Error(`Pagila source unavailable: ${response.status}`);
  return response.text();
};
const [schema, data, license] = await Promise.all(['pagila-schema.sql','pagila-insert-data.sql','LICENSE.txt'].map(source));
const definitions = [];
for (const table of tables) {
  const match = schema.match(new RegExp(`CREATE TABLE public\\.${table} \\(([\\s\\S]*?)\\n\\)`));
  if (!match) throw new Error(`Missing definition: ${table}`);
  const body = match[1]
    .replace(/ DEFAULT nextval\('[^']+'::regclass\)/g, '')
    .replace(/ DEFAULT uuidv7\(\)/g, '')
    .replace(/ GENERATED ALWAYS AS \((.*?)\) VIRTUAL/g, ' GENERATED ALWAYS AS ($1) STORED');
  definitions.push(`CREATE TABLE public.${table} (${body}\n);`);
}
const inserts = new Map(tables.map(name => [name, []]));
for (const line of data.split('\n')) {
  const match = line.match(/^INSERT INTO public\.(\w+) VALUES (.*);$/);
  if (!match) continue;
  const table = match[1].replace(/^payment_p\d{4}_\d{2}$/, 'payment');
  inserts.get(table)?.push(match[2]);
}
const constraints = [];
for (const match of schema.matchAll(/ALTER TABLE (?:ONLY )?public\.(\w+)\s+ADD CONSTRAINT (\w+) (PRIMARY KEY|FOREIGN KEY) ([\s\S]*?);/g)) {
  const table = match[1].replace(/^payment_p\d{4}_\d{2}$/, 'payment');
  if (!tables.includes(table)) continue;
  const clause = `ALTER TABLE public.${table} ADD ${match[3]} ${match[4]};`;
  if (match[3] === 'PRIMARY KEY' && table === 'payment') continue; // Already inline in the parent definition.
  if (!constraints.includes(clause)) constraints.push(clause);
}
const header = `-- Pagila core sample, upstream ${revision}, PostgreSQL License.\n-- Adaptations: 15 core tables only; payment partitions flattened; generated column stored;\n-- sequence/uuid defaults omitted (all values supplied); no extensions, functions, triggers or private data.\n`;
const chunks = [header, "CREATE TYPE public.mpaa_rating AS ENUM ('G','PG','PG-13','R','NC-17');", 'CREATE DOMAIN public.year AS integer CHECK (VALUE BETWEEN 1901 AND 2155);', ...definitions];
for (const [table, values] of inserts) {
  if (!values.length) throw new Error(`No sample rows for ${table}`);
  for (let i = 0; i < values.length; i += 500) chunks.push(`INSERT INTO public.${table} VALUES\n${values.slice(i,i+500).join(',\n')};`);
}
chunks.push(...constraints);
// Index relationship columns so the exploratory joins stay responsive in the browser.
for (const clause of constraints) {
  const match = clause.match(/ALTER TABLE public\.(\w+) ADD FOREIGN KEY \(([^)]+)\)/);
  if (match) chunks.push(`CREATE INDEX ON public.${match[1]} (${match[2]});`);
}
chunks.push('ANALYZE;');
const sql = chunks.join('\n\n');
await mkdir('public/practice/datasets', {recursive:true});
await mkdir('docs/legal', {recursive:true});
await writeFile('public/practice/datasets/pagila-core.sql',sql);
await writeFile('docs/legal/Pagila-PostgreSQL.txt',license);
await writeFile('public/practice/datasets/pagila-manifest.json',JSON.stringify({source:base,revision,license:'PostgreSQL License',sha256:createHash('sha256').update(sql).digest('hex'),tables:Object.fromEntries([...inserts].map(([name,rows])=>[name,rows.length]))},null,2)+'\n');
const db = await PGlite.create();
try {
  await db.exec(sql);
  const columns = await db.query("SELECT table_name,column_name,data_type,is_nullable,ordinal_position FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name,ordinal_position");
  const constraints = await db.query("SELECT conrelid::regclass::text AS table_name,contype AS kind,pg_get_constraintdef(oid) AS definition FROM pg_constraint WHERE connamespace='public'::regnamespace AND contype IN ('p','f') ORDER BY conrelid::regclass::text,contype");
  await writeFile('public/practice/datasets/pagila-schema.json',JSON.stringify({columns:columns.rows,constraints:constraints.rows},null,2)+'\n');
} finally { await db.close(); }
console.log(JSON.stringify({tables:tables.length,rows:[...inserts.values()].reduce((sum,rows)=>sum+rows.length,0),bytes:Buffer.byteLength(sql)}));
