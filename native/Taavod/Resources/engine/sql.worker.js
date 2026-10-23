import { sqlFixture } from './fixtures.js';
import { equivalentResults } from './compare.js';
let runtime;
let explorationDb;
function loadRuntime() {
    if (!runtime) {
        runtime = (async () => {
            self.postMessage({ status: 'Loading PostgreSQL…' });
            const runtimePath = '/packs/sql/index.js';
            const [{ PGlite }, pgliteWasmModule, initdbWasmModule, fsBundle] = await Promise.all([
                import(/* webpackIgnore: true */ /* turbopackIgnore: true */ runtimePath),
                WebAssembly.compileStreaming(fetch('/packs/sql/pglite.wasm')),
                WebAssembly.compileStreaming(fetch('/packs/sql/initdb.wasm')),
                fetch('/packs/sql/pglite.data').then((response) => {
                    if (!response.ok)
                        throw new Error('PostgreSQL runtime missing. Run the runtime asset setup.');
                    return response.blob();
                }),
            ]);
            return { PGlite, pgliteWasmModule, initdbWasmModule, fsBundle };
        })();
    }
    return runtime;
}
async function loadExplorationDatabase() {
    if (!explorationDb) {
        const pending = (async () => {
            const modules = await loadRuntime();
            self.postMessage({ status: 'Loading the full Pagila sample into your browser…' });
            const snapshotResponse = await fetch('/datasets/pagila.pgdata.gz');
            if (!snapshotResponse.ok)
                throw new Error('The Pagila sample database could not be loaded.');
            const db = await modules.PGlite.create({ ...modules, loadDataDir: await snapshotResponse.blob() });
            try {
                self.postMessage({ status: 'Pagila sample ready.' });
                return db;
            }
            catch (error) {
                await db.close();
                throw error;
            }
        })().catch((error) => {
            if (explorationDb === pending)
                explorationDb = undefined;
            throw error;
        });
        explorationDb = pending;
    }
    return explorationDb;
}
async function checkAnswer(answer, solution) {
    const modules = await loadRuntime();
    let passed = true;
    let firstResults = [];
    for (let variant = 0; variant < 2; variant++) {
        self.postMessage({ status: `Checking practice fixture ${variant + 1} of 2…` });
        const db = await modules.PGlite.create(modules);
        try {
            await db.exec(sqlFixture(variant));
            const expected = await db.exec(solution);
            await db.exec("BEGIN; SET LOCAL statement_timeout='5s'; SET TRANSACTION READ ONLY;");
            const actual = await db.exec(answer);
            const actualSets = actual.filter((set) => set.fields.length);
            if (!variant)
                firstResults = actualSets;
            if (!equivalentResults(actualSets, expected.filter((set) => set.fields.length)))
                passed = false;
        }
        finally {
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
async function runExplorationQuery(answer, tableName) {
    const db = await loadExplorationDatabase();
    await db.exec("BEGIN; SET LOCAL statement_timeout='8s'; SET TRANSACTION READ ONLY;");
    try {
        const result = await db.query(answer);
        const rows = result.rows;
        self.postMessage({ exploreResult: {
                fields: result.fields,
                rows: rows.slice(0, 100),
                rowCount: rows.length,
                tableName,
            } });
    }
    finally {
        await db.exec('ROLLBACK').catch(() => undefined);
    }
}
self.onmessage = async (event) => {
    try {
        if (event.data.mode === 'explore')
            await runExplorationQuery(event.data.answer, event.data.tableName);
        else
            await checkAnswer(event.data.answer, event.data.solution);
    }
    catch (error) {
        self.postMessage({ error: error instanceof Error ? error.message : typeof error === 'object' ? JSON.stringify(error) : String(error) });
    }
};
