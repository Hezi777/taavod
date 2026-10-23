# Architecture

Taavod is a native macOS app. The active app entry point is `native/Taavod/TaavodApp.swift`; `UI/` contains the shell and career screens, `Learning/` contains study and editor views, `Coach/` contains assistant behavior, and `Core/` owns app state, persistence, runtime packs, and exercise execution.

## Workspace and credentials

`WorkspaceStore` persists typed workspace records in SwiftData at `~/Library/Application Support/Taavod/workspace.sqlite`. Each record keeps its domain payload as JSON. The app also keeps downloaded runtimes and migration files under the same Application Support directory. Credentials for Anthropic, Groq, and Tavily are stored in macOS Keychain; never place them in source, runtime files, or workspace records.

The curriculum, practice fixtures, Pagila sample, and runtime manifest are generic bundled resources. Personal workspace data and original source photos do not belong in the repository. The bundled Shih Tzu icon and other approved derived mascot artwork are permitted assets.

## Exercise boundary

`ExerciseRunner` hosts SQL and Python workers in WebKit. It starts a loopback-only `RuntimeAssetServer` that serves files from the generic resource bundle and the verified runtime cache. The server has no workspace or Keychain routes. Keep learner code and results inside the exercise runtime and app; do not send them to a grading service.

PGlite and Pyodide are pinned in `Resources/runtime-manifest.json`. `RuntimePacks` downloads each pack on demand to Application Support and verifies every file with its manifest SHA-256 before use. Changes to versions, URLs, hashes, or pack paths must keep the manifest and downloader aligned.

The bundled Pagila database supports local SQL exploration. The runner separates exploratory queries from exercise checks and uses disposable fixtures for checks. Python and SQL run in WebKit, not on a server.

## Coach and external services

The Coach reads limited screen, draft, and selection context from the app. When a user sends a message, the selected Anthropic or Groq provider receives that context. Optional Tavily search and public company feeds make network requests only when the related search is used. Keep provider keys in Keychain and preserve the user-facing context disclosure in Coach Settings.

The active branch contains the native app. The original React source is preserved at the private repository tag `legacy-react` (`9a11bdb`).
