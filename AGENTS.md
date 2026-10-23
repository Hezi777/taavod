# Taavod

Taavod is a private, local-first macOS app for BI learning, SQL/Python practice, and career preparation. The active product is native SwiftUI. The previous React implementation is preserved in the private repository's `legacy-react` tag (`9a11bdb`).

## Map

- `native/Taavod`: SwiftUI interface, app state, SwiftData workspace, WebKit exercise runtime, curriculum, and generic fixtures.
- `native/TaavodTests`: native unit and runtime tests.
- `docs/`: product setup, architecture, verification, and design notes.

For native conventions and build details, read [native/AGENTS.md](native/AGENTS.md). Read [agent_docs/architecture.md](agent_docs/architecture.md) before changing persistence, runtime boundaries, or credentials. Read [agent_docs/verification.md](agent_docs/verification.md) before changing runtime behavior or tests.

## Working here

Build and test the macOS app from `native/` with `./scripts/build.sh` and `./scripts/test.sh`. The legacy web workflow is available only through the `legacy-react` tag.

Keep workspace records in the local user data store and provider credentials in Keychain. Bundle only generic curriculum, fixtures, and approved derived mascot artwork; never add personal records, source photos, uploaded documents, or credentials.
