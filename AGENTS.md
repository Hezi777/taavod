# Career Helper

Private BI learning, practice and career preparation for Hen. The default backend is local Supabase through Docker/OrbStack; public signup is disabled.

## Map

- `src/app/(workspace)`: product screens; `src/components/career`: shell and shared presentation.
- `src/lib/curriculum.ts` and `src/lib/practice`: generic lessons, exercises and disposable browser runtimes.
- `src/lib/server`: authentication, owner-scoped storage and encrypted provider connections.
- `supabase/migrations`: database policies, private uploads and server-only tables.
- `scripts/import-career.ts`: private personal preload, separate from onboarding.

## Working here

Use Node 24 and pnpm. Start services with `pnpm services:start`, configure/import with `pnpm local:setup`, then `pnpm dev` on loopback port 3100.

The done checks are `pnpm typecheck`, `pnpm lint`, `pnpm test`, and `pnpm build`. Use Playwright CLI for interface checks; keep captures in ignored `output/`.

Read `agent_docs/architecture.md` before storage, provider or runtime changes. Read `agent_docs/verification.md` before verification or auth/policy changes. Operational setup is in `docs/SETUP.md`.

Preserve the private import boundary: no personal seed records, uploads, provider credentials or browser sessions in public assets. Keep generated runtime distributions ignored; the build copies them from installed dependencies.

<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
