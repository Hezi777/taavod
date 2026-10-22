# Architecture

The app shell is `src/components/career/shell.tsx`; workspace routes are grouped under `src/app/(workspace)`. It uses a shared client provider in `src/lib/career-store.tsx`, backed by authenticated `/api/state` requests.

`src/lib/types.ts` defines the domain records. `src/lib/validation.ts` validates merged records before partial updates. Supabase `career_records` stores versionable typed JSON payloads by `(user_id, kind, id)`; owner policies enforce isolation. Atomic database merges retain unrelated concurrent field edits. Reads paginate beyond the default 1,000-row API limit.

`src/lib/server` owns identity, private storage, encryption, provider models and usage. Server-only integration rows have no authenticated/anonymous grants. The AES-GCM key comes from the server environment. Evidence downloads verify ownership and return attachments rather than public storage URLs.

Generic curriculum is authored in `src/lib/curriculum.ts` and the Pagila module. PGlite runs isolated fixtures in a browser worker. It must load the untouched copied ESM runtime: Turbopack's rewritten window detection broke the bundled import. `copy-runtime.mjs` prepares assets before development and production builds. Pyodide uses a pinned external runtime/package source.

SQL exploration uses a separate PGlite instance loaded on demand with the pinned public Pagila core sample (15 tables, 121,209 rows). It never connects to private Supabase. `scripts/prepare-pagila.mjs` derives the compatible seed and introspects its exact key/column metadata for the schema explorer and CodeMirror completion. Exploration executes read-only queries; graded tasks still run fresh independent synthetic fixtures. The modeling, pipeline and metric illustrations calculate their own small examples and do not award practice passes.

The private workspace layout keeps a single coach session mounted while the compact/expanded visual window opens and closes. Provider/model selection is per request; the authenticated server validates overrides against the chosen provider's model list and keeps API keys server-only. It does not overwrite the provider's saved default model.

Job search and URL capture are separate from saving. Capture uses validated public DNS pinned to HTTPS requests, validates every redirect, and bounds size/time. Imported text is untrusted reference material. Deduplication keeps identity-bearing query fields and canonicalizes recognized LinkedIn job IDs.

The personal importer is not a generic onboarding fixture. It remains a private setup tool. User accounts without imported state receive onboarding; owner data does not appear in client source or public assets.

File-backed fallback exists only for troubleshooting outside production. Local Supabase is the default operating backend for this installation. The Vercel linkage does not make the local database internet-accessible.
