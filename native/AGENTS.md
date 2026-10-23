# Taavod for macOS

Native, local-first BI learning and career preparation. SwiftUI owns every visible screen; isolated WebKit workers execute SQL and Python exercises.

- `Taavod/Core`: storage, curriculum, runtime packs and exercise execution.
- `Taavod/UI`, `Learning`, `Coach`, `Mascot`: native interface and contextual assistant.
- `Taavod/Resources`: generic curriculum and practice fixtures only. Never add personal records or credentials.
- Generate the Xcode project with `xcodegen generate` in this directory. Build and test with the `Taavod` scheme, macOS destination, and `CODE_SIGNING_ALLOWED=NO`.

Use Swift 6, main-actor UI state, SF Symbols and system Liquid Glass APIs. Keep glass in navigation and controls; keep reading and editing surfaces legible. Pause animation and runtime work when inactive.

Read the shared Core types before changes. Keep learner code, result provenance and self-reviewed work distinct from verified passes. Credentials belong in Keychain and never cross the exercise bridge.
