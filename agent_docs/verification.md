# Verification

Run `pnpm typecheck`, `pnpm lint`, `pnpm test`, and `pnpm build` before declaring changes done.

Tests cover result-based SQL/Python grading, two data fixtures, imported exercise coverage, review scheduling, job identity and filtering, URL/network restrictions, merged-record validation, pagination, provider error handling and file boundaries. Isolation tests execute the actual migration in PGlite with auth/storage stubs and two identities; repeat smoke checks against local Supabase when changing auth or policies.

Use Playwright CLI for browser automation. Isolate sessions by feature, snapshot before using element references, and save captures under ignored `output/playwright/`. Do not use the in-app browser extension for automation.

Verify code execution through the interface: valid alternate solution, wrong result, invalid syntax, cancellation, reset, and reload persistence. Check Python chart output. Written and external work must remain labeled self-reviewed.

For job changes verify preview → save → stage/notes/follow-up → reload, clearing dates, historical filters, deduplication and visible import errors. For identity changes verify anonymous denial, non-owner denial, sign-in/out, private downloads and fresh onboarding.

Exercise provider behavior with mocks unless the user has configured a real key. Never invent a live-provider validation result. Keep test records distinct from Hen's records and remove only known QA records afterward.

Generated PGlite distribution files and private `.local/` data are ignored and excluded from authored-source lint. Runtime assets are recreated by the build script; never commit uploaded CVs, local state, keys, credential status output or browser auth state.
