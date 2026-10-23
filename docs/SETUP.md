# Build and operate Taavod

Taavod is a native macOS app. The normal build and app use do not require Node.js, Docker, Supabase, or a web server.

## Requirements

- Apple silicon Mac running macOS 26 or later
- Xcode with the macOS 26 SDK
- XcodeGen

## Build and launch

From the repository root:

```sh
cd native
./scripts/build.sh
open build/Build/Products/Release/Taavod.app
```

The build script generates `Taavod.xcodeproj` from `project.yml` and builds the Release app for arm64.

## Package the app

The current installer is [Taavod-1.0.0-arm64.dmg](https://github.com/Hezi777/taavod/releases/download/v1.0.0/Taavod-1.0.0-arm64.dmg). It is ad hoc signed and not notarized. Its SHA-256 is `c7d1f6cab39825f697146f3c4654cd4bec571d2c3b346dff15ff1bb9c20b6828`.

To build a new disk image, first build the Release app as above. Packaging requires the macOS command line tools `hdiutil`, `codesign`, `swiftc`, `python3`, and `ditto`, plus the Python packages `ds-store` and `mac-alias`. Then run from the repository root:

```sh
python3 -m pip install ds-store mac-alias
./native/scripts/package.sh
```

The script writes `native/output/Taavod-1.0.0-arm64.dmg` and refuses to overwrite an existing image. The packaged app is ad hoc signed; this process does not notarize it.

## Runtime packs

The SQL and Python engines are downloaded only when first needed. `Resources/runtime-manifest.json` pins their versions, source URLs, sizes, and SHA-256 checksums. Taavod checks every downloaded file before using it and stores valid packs under `~/Library/Application Support/Taavod/Runtimes/`.

The app needs an internet connection to fetch an uncached runtime. Core workspace features and bundled lessons remain available without provider credentials. Coach requests need an Anthropic or Groq API key; optional Tavily search needs its own key. Add and remove keys in Coach Settings; they are kept in Keychain. Coach Settings explains what context is shared with a provider.

## Local data

SwiftData stores workspace records at `~/Library/Application Support/Taavod/workspace.sqlite`. Evidence files, runtime packs, pending migrations, and backups also live in this Taavod support folder. Use Settings to export or remove workspace data. The bundled curriculum, practice fixtures, and Pagila dataset contain generic learning material, not personal workspace records.

## Optional transfer from the legacy web app

The original web implementation is preserved at the `legacy-react` tag. To prepare a local transfer, the legacy project must have its local Supabase stack running and a valid `.env.local`. From the repository root, run:

```sh
node native/scripts/migrate-legacy.mjs /path/to/legacy-project
```

The script reads the loopback-only legacy Supabase instance, creates a private backup, copies evidence files into Taavod's Application Support folder, and stages records and any decryptable provider keys for import. Launch Taavod to complete the staged import; keys are then written to Keychain. If the old workspace has provider keys, its `INTEGRATION_ENCRYPTION_KEY` must be available in the legacy `.env.local`. The transfer script does not modify the legacy database.

## Tests

From `native/`:

```sh
./scripts/test.sh
```

The test script fetches missing pinned runtime files into the ignored `.runtime-cache/`, verifies their hashes, generates the Xcode project, and runs the `Taavod` scheme on macOS arm64. A first test run needs network access. Tests use provider mocks and do not need live AI credentials.
