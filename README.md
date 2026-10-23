<p align="center"><img src="native/Taavod/Resources/Mascot/ShihTzu-Icon.png" width="144" alt="Taavod Shih Tzu icon" /></p>
<h1 align="center">Taavod</h1>
<p align="center">A native Mac workspace for learning BI, practicing SQL and Python, and preparing for your next role—with local-first storage.</p>
<p align="center">
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white" />
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?style=for-the-badge&logo=swift&logoColor=white" />
  <img alt="macOS 26+" src="https://img.shields.io/badge/macOS-26%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img alt="Apple silicon" src="https://img.shields.io/badge/Apple_silicon-arm64-555555?style=for-the-badge&logo=apple&logoColor=white" />
</p>
<p align="center"><a href="#about">About</a> · <a href="#features">Features</a> · <a href="#tech-stack">Tech stack</a> · <a href="#getting-started">Getting started</a> · <a href="docs/DESIGN.md">Design notes</a></p>

## About

Taavod brings BI study, coding practice, portfolio evidence, job search, interview preparation, and a contextual coach into one macOS app. Its curriculum and practice fixtures are generic; workspace records stay in the user’s local Application Support folder, and provider keys stay in macOS Keychain.

SwiftUI owns the visible app. A separate WebKit worker runs SQL and Python exercises, with a narrow local asset server that serves generic runtime files only. The desktop app does not need Node.js, Docker, or a web backend to run.

The original React implementation is preserved at the private repository’s `legacy-react` tag (`9a11bdb`). The active branch contains the native app.

## Features

| Area | Included |
|---|---|
| Learn | 10 tracks and 30 lessons with examples and sources |
| Practice | 81 SQL, Python, quiz, and written exercises; SQL and Python run in isolated WebKit workers |
| Data | Bundled Pagila sample for SQL exploration; learner drafts and results stored separately |
| Career | Job tracking and search, portfolio projects and evidence, timed interview practice |
| Coach | Context-aware chat with Anthropic or Groq; optional Tavily job search; keys stored in Keychain |
| Privacy | Local SwiftData workspace, JSON export, generic bundled curriculum and fixtures |

Coach requests send the current screen context and draft to the selected provider. Written and external-tool exercises are self-reviewed; Taavod does not present them as automatically graded.

## Tech stack

| Layer | Technology |
|---|---|
| App and interface | Swift 6, SwiftUI, AppKit |
| Local workspace | SwiftData with JSON record payloads |
| Exercise runtime | WebKit workers, PGlite 0.5.10, Pyodide 314.0.7 |
| Runtime integrity | Versioned manifest with SHA-256 file checks |
| Credentials | macOS Keychain |
| Tests | Swift Testing, `xcodebuild` |

## Getting started

Requirements: Apple silicon Mac, macOS 26 or later, Xcode with the macOS 26 SDK, and XcodeGen.

```sh
cd native
./scripts/build.sh
open build/Build/Products/Release/Taavod.app
```

The scripts generate the Xcode project and build for arm64. Taavod downloads the pinned SQL or Python runtime pack when first needed; it verifies each downloaded file against the bundled manifest. Exercise use and test runtime preparation need an internet connection. No live AI key is needed to build or run the tests.

Run the test suite from `native/`:

```sh
./scripts/test.sh
```

The current arm64 installer is [Taavod-1.1.0-arm64.dmg](https://github.com/Hezi777/taavod/releases/download/v1.1.0/Taavod-1.1.0-arm64.dmg). It is ad hoc signed and not notarized, so macOS may require allowing it in Privacy & Security before opening. SHA-256: `1973ca434a8a1e04f24b51697d61561ede3741dd09858a6a3bf56dc968c5730c`. See [setup and operation](docs/SETUP.md) for build and packaging steps, [architecture](agent_docs/architecture.md) for privacy boundaries, and [verification](agent_docs/verification.md) for test scope. See [design notes](docs/DESIGN.md) for the visual reference and mascot status.

This is a private project. No open-source license is granted.
