# Verification

Run the native suite from `native/` before finishing a change:

```sh
./scripts/test.sh
```

The script prepares the pinned PGlite and Pyodide test packs in the ignored `.runtime-cache/`, generates the Xcode project, then runs the `Taavod` scheme on macOS arm64 with code signing disabled. A first run needs network access to fetch packs; valid cached files are reused. The suite covers workspace persistence and migration, lesson-to-exercise grouping, exact lesson navigation with draft preservation, cursor normalization and smoothing, coach context and mock response parsing, and SQL/Python execution including alternate answers, failures, plots, and cancellation. It does not require a live provider key.

Latest verification: all 25 tests pass, and the Release build passes. The distributable DMG is ad hoc signed and not notarized; see [setup](../docs/SETUP.md) for its location and checksum.

Build the local app with `./scripts/build.sh`. For interface changes, launch the built app and check the affected screen in both light and dark appearance, at the minimum window size, and with Reduce Motion enabled where motion is involved. Confirm that runtime, editor, and record actions still preserve learner progress.

Keep generic test fixtures separate from real workspace records. Never test with private career data, uploaded files, API keys, or browser credentials in source or committed artifacts.

The 1.1.0 screen-by-screen audit and remaining manual coverage are recorded in [UX audit](../docs/UX-AUDIT.md).
