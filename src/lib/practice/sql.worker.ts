import { sqlFixture } from './fixtures';
import { equivalentResults, type ResultSet } from './compare';

type Request =
 | { mode: 'check'; answer: string; solution: string }
 | { mode: 'explore'; answer: string; tableName?: string };

type BrowserDatabase = {
 exec: (query: string) => Promise<ResultSet[]>;
 query: (query: string) => Promise<ResultSet>;
 close: () => Promise<void>;
};

type BrowserRuntime = {
 PGlite: { create: (options: { pgliteWasmModule: WebAssembly.Module; initdbWasmModule: WebAssembly.Module; fsBundle: Blob }) => Promise<BrowserDatabase> };
 pgliteWasmModule: WebAssembly.Module;
 initdbWasmModule: WebAssembly.Module;
 fsBundle: Blob;
};

let runtime: Promise<BrowserRuntime> | undefined;
let explorationDb: Promise<BrowserDatabase> | undefined;

function loadRuntime(): Promise<BrowserRuntime> {
 if (!runtime) {
  runtime = (async () => {
   self.postMessage({ status: 'Loading PostgreSQL…' });
   const runtimePath = '/practice/runtime/index.js';
   const [{ PGlite }, pgliteWasmModule, initdbWasmModule, fsBundle] = await Promise.all([
    import(/* webpackIgnore: true */ /* turbopackIgnore: true */ runtimePath) as Promise<typeof import('@electric-sql/pglite')>,
    WebAssembly.compileStreaming(fetch('/practice/runtime/pglite.wasm')),
    WebAssembly.compileStreaming(fetch('/practice/runtime/initdb.wasm')),
    fetch('/practice/runtime/pglite.data').then((response) => {
     if (!response.ok) throw new Error('PostgreSQL runtime missing. Run the runtime asset setup.');
     return response.blob();
    }),
   ]);
   return { PGlite, pgliteWasmModule, initdbWasmModule, fsBundle };
  })();
 }
 return runtime;
}

async function loadExplorationDatabase(): Promise<BrowserDatabase> {
 if (!explorationDb) {
  const pending = (async () => {
   const modules = await loadRuntime();
   self.postMessage({ status: 'Loading the full Pagila sample into your browser…' });
   const db = await modules.PGlite.create(modules);
   try {
    const seedResponse = await fetch('/practice/datasets/pagila-core.sql');
    if (!seedResponse.ok) throw new Error('The Pagila sample database could not be loaded.');
    await db.exec(await seedResponse.text());
    self.postMessage({ status: 'Pagila sample ready.' });
    return db;
   } catch (error) {
    await db.close();
    throw error;
   }
  })().catch((error: unknown) => {
   if (explorationDb === pending) explorationDb = undefined;
   throw error;
  });
  explorationDb = pending;
 }
 return explorationDb;
}

async function checkAnswer(answer: string, solution: string) {
 const modules = await loadRuntime();
 let passed = true;
 let firstResults: ResultSet[] = [];
 for (let variant = 0; variant < 2; variant++) {
  self.postMessage({ status: `Checking practice fixture ${variant + 1} of 2…` });
  const db = await modules.PGlite.create(modules);
  try {
   await db.exec(sqlFixture(variant));
   const expected = await db.exec(solution);
   await db.exec("BEGIN; SET LOCAL statement_timeout='5s'; SET TRANSACTION READ ONLY;");
   const actual = await db.exec(answer);
   const actualSets = actual.filter((set) => set.fields.length) as ResultSet[];
   if (!variant) firstResults = actualSets;
   if (!equivalentResults(actualSets, expected.filter((set) => set.fields.length) as ResultSet[])) passed = false;
  } finally {
   await db.close();
  }
 }
 self.postMessage({ result: {
  passed,
  results: firstResults,
  checks: 2,
  feedback: passed
   ? 'Results match the reference on both synthetic practice fixtures. Explain the grain and verify assumptions before calling the skill fluent.'
   : 'The output differs on at least one practice fixture. Check column order, missing rows, duplicate amounts, tie handling, and the number of result sets. Row order and column aliases are ignored.',
 } });
}

async function runExplorationQuery(answer: string, tableName?: string) {
 const db = await loadExplorationDatabase();
 await db.exec("BEGIN; SET LOCAL statement_timeout='8s'; SET TRANSACTION READ ONLY;");
 try {
  const result = await db.query(answer);
  const rows = result.rows as Record<string, unknown>[];
  self.postMessage({ exploreResult: {
   fields: result.fields,
   rows: rows.slice(0, 100),
   rowCount: rows.length,
   tableName,
  } });
 } finally {
  await db.exec('ROLLBACK').catch(() => undefined);
 }
}

self.onmessage = async (event: MessageEvent<Request>) => {
 try {
  if (event.data.mode === 'explore') await runExplorationQuery(event.data.answer, event.data.tableName);
  else await checkAnswer(event.data.answer, event.data.solution);
 } catch (error) {
  self.postMessage({ error: error instanceof Error ? error.message : typeof error === 'object' ? JSON.stringify(error) : String(error) });
 }
};
