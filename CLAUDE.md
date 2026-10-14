# Coding standards

Clean layered design, KISS, Single Responsibility, standard practice.
**Clean separation between layers and responsibilities is the biggest concern.**
Prefer the simpler option when in doubt.

## Summary
1. **Architecture**: pure-Dart `core`, thin Flutter `app` with MVVM; one wiring point.
2. **Interfaces**: state the question, hide what varies (sync tool, platform).
3. **Robustness**: no dirty fixes or caches; never lose user data; byte-exact edits.
4. **Quality**: trusted libraries over own code; small files; tests with every change.

---

## 1. Architecture
### Layers
- `core` = pure Dart, no UI; `app` = thin Flutter layer that uses only core's public interfaces.
- Lower layers never know upper ones; they get what they need passed in (storage gets a `TempFileNamer`, not the sync adapter).
- App-level housekeeping stays in the app, not in a per-folder service (e.g. backup pruning).

### App: MVVM (Flutter's official architecture guide)
- Widgets only render state and forward events; they keep dialogs only.
- Controllers / view models own UI flows (create, delete + undo, save + refresh).
- Services / repositories do the I/O. Riverpod = thin glue, no codegen. Feature folders.
- Pattern: plain class behind a Riverpod `Provider` taking `Ref`, or an autoDispose family `Notifier` for per-screen state.

### Wiring
- One wiring point picks implementations (`FolderServices`); tool-specific wiring in its own file.
- Platform facts (e.g. Flatpak can't see parent folders) go into constructors there, never into interfaces.

## 2. Interface design: encapsulate what varies
Names: *information hiding* (Parnas), *encapsulate what varies*, avoid *leaky abstractions*.
- An interface states the question, not how one implementation answers it. No parameters, return types or concepts only some implementations need (e.g. a marker file name, a "parents visible" flag).
- Push decisions that differ per implementation (sync tool, platform) behind the interface; inject platform facts into the implementation's constructor in the wiring layer.
- Check before review: "Would a sync tool that works via a DB/API instead of files fit this interface unchanged?"
- Sync-tool neutral: each tool brings its own conflict source, folder scanner and sync check; generic code never parses tool file names.
- One type, one meaning: opaque version apart from display time (`FileVersion` + `modified`); opaque ids instead of paths (`ConflictCopy.id`).
- Pure units: a conflict handler knows only its file type; file→type mapping lives outside (`FileTypeDetector` + map).
- Validate at the edge: parse-only constructors (`RelPath.parse`). One owner per policy (`FileFilter` owns which files exist for us).

## 3. Robustness
### No shortcuts
- No dirty fixes or workarounds to force things to work. If something doesn't fit, rethink the design.
- No caches to hide a design problem; fix the structure (e.g. one-pass `FolderScanner` instead of a listing cache).
- Expected failures = result values; exceptions only for bugs.

### Data safety
- Never lose user text: if a save can't land in the note, keep it as a synced conflict copy.
- Never silently recreate a deleted file or folder; stop and ask. A write never creates a user folder's root (`LocalFileStore`; only app storage may: `createsRoot`); subfolders below it may be recreated to hold a conflict copy of unsaved edits.
- No automatic writes into synced folders: only user actions, plus a conflict copy when edits can't be saved, so devices can't ping-pong and use up the sync tool's history. Proven by `app/test/safety/`.
- Byte-exact edits: change only the touched lines; no parse-and-reprint editors (they reformat files and cause sync conflicts).
- Concurrency: a refresh after a write starts after that write (`FreshRuns`); take a file's version from the temp file before rename.

## 4. Quality
### Libraries
- A trusted, maintained library beats own code we must test and maintain; own code only where no trusted library fits these rules (e.g. `flutter_markdown_plus` for rendering; own checklist line model, since edits must stay byte-exact).
- Only well-trusted dependencies; pin where normal: GitHub Actions by commit SHA (official actions preferred), Flutter SDK by version, Dart packages via the committed lock file, Gradle wrapper by hash. Version pinning is enough where hash pinning isn't normal (Android SDK, OS packages, runner images, Flatpak runtime). Report any place where pinning isn't possible.

### Size
- Small files and widgets; split when a unit does two jobs.

### Tests
- Every feature or change ships with new or updated tests; no PR without them.
- Every bug fix gets a test that fails without it.
- CI stays green; never skip or disable a test to get there.
- Unit tests for core and app controllers; Linux UI tests in CI for user flows.
- Adversarial self-review of the diff before asking for review.
