# Setup and operation

## Local Supabase

The `career-helper` stack uses Docker with OrbStack. It has its own containers, volumes and bridge network; it does not reuse the existing `elite-local` installation.

| Service | Local URL / port |
|---|---|
| Web app | http://127.0.0.1:3100 |
| Supabase API | http://127.0.0.1:55321 |
| PostgreSQL | 127.0.0.1:55322 |
| Supabase Studio | http://127.0.0.1:55323 |
| Sign-in email inbox | http://127.0.0.1:55324 |

The Docker network uses `com.docker.network.bridge.host_binding_ipv4=127.0.0.1`. Keep this loopback binding when recreating the stack.

```sh
pnpm services:start
pnpm local:setup
pnpm dev
```

`local:setup` reads the Supabase CLI's status in memory and writes ignored `.env.local` without printing keys. It keeps the existing integration encryption key if present, creates the configured owner account through the local admin API, and imports approved data without overwriting existing records.

Sign-in is a real Supabase magic-link session. Enter the owner email on the login page, open the local inbox, and use its sign-in link. Messages remain on this Mac. Public account registration is disabled.

Stop the containers with `pnpm services:stop`; volumes are retained. Do not use `supabase db reset`, Docker volume removal, or OrbStack reset unless you intend to remove stored data.

## Private import

The approved import is deliberately narrow:

- `job-search/data/jobs_merged.jsonl`: all 1,228 historical leads, preserving descriptions and provenance.
- Current professional profile facts and six project entries, including archived work.
- `cv/Hen-Zrihen-CV.pdf`: stored as a private file.
- Initial weekly tasks; no invented practice or application history.

Financial/work-permit documents are excluded. The 27 existing SQL prompts are already represented in the generic curriculum with source provenance and fixture adaptations.

Set `CAREER_IMPORT_PATH` for a different source folder. The personal import script is Hen-specific and must remain private. A fresh user should use onboarding instead of running that script.

Imports preserve existing IDs and edits. Re-running the import does not refresh vacancy status or reset progress.

## Environment

Only the Supabase URL and publishable key may be browser-visible. The server key and encryption key stay server-side.

| Variable | Role |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Local or hosted project API URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Public client credential; owner policies still apply |
| `SUPABASE_SECRET_KEY` | Server-only admin operations for encrypted integrations and setup |
| `OWNER_EMAIL` | Allowed account for the private installation |
| `INTEGRATION_ENCRYPTION_KEY` | Base64-encoded 32-byte AES-GCM encryption key |
| `NEXT_PUBLIC_LOCAL_INBOX_URL` | Local-only sign-in inbox link |
| `MULTI_USER_ENABLED` | Explicit future opt-in; defaults false |
| `LOCAL_DEV_MODE` | File-backed fallback only; defaults 0 for real Supabase |

Back up the encryption key together with the database through an appropriate private backup. Replacing it makes saved provider credentials unreadable; reconnect those providers after rotation.

## Migrations

The initial migration creates owner-scoped records, a private evidence bucket, server-only encrypted integration rows and server-only AI usage counters. New local migrations should be generated with `supabase migration new <name>` and applied with the CLI's local migration command. Review SQL and run isolation tests before applying it.

`pnpm db:apply` is a Management API fallback for applying the initial schema to a new hosted project. It requires scoped `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` in the shell environment. Do not use it as a substitute for migration history on an existing managed database.

## AI and live search

In Settings → Connections, enter an Anthropic, Groq or Tavily key. The server validates it and stores ciphertext, never a browser-side secret. Anthropic/Groq model choices come from each provider's current model list. Replacing or removing a connection affects only that account.

The coach sends the selected workspace context to the chosen provider. It does not submit job applications, contact employers, execute user code on the server or claim its feedback is an objective hiring assessment. Token counts are usage totals, not a billing estimate.

Public Greenhouse and Lever feeds work without a Tavily key. A successful page fetch is not proof that applications are open. September 2026 imports remain historical until checked again.

## Future hosted deployment

A Vercel project is linked, but the current backend is intentionally local. To host the complete system, provision a reachable private Supabase project, apply the migration, configure the same environment names with `LOCAL_DEV_MODE=0`, set auth redirect URLs, disable signup, import through `--supabase`, and verify owner sign-in and uploads before deployment. Do not expose the local database to the internet as a shortcut.

For development fallback only, `LOCAL_DEV_MODE=1` uses `.local/` on the server. It works only outside production and outside Vercel. This mode does not provide cross-device sync or real Supabase authentication.

## A fresh workspace for someone else

Start services, then run `OWNER_EMAIL=you@example.com pnpm local:setup --empty`. This creates the private owner without importing Hen’s career material. Sign in through the local inbox and complete onboarding. Existing database records are retained. Run this only when you intend to change the installation’s allowed owner; public signup remains disabled.

## Visual design and companion

See [DESIGN.md](DESIGN.md) for the supplied interface references, the live animated head, and Bloub attribution. The companion runs in the browser without Swift or Blender.
