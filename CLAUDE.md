# Coding standards

Clean layered design, KISS, Single Responsibility, standard practice.
Clean separation between layers and responsibilities is the biggest concern.
Prefer the simpler option when in doubt.

## Architecture
- `core` is pure Dart with no UI; `app` is a thin Flutter layer that uses only core's public interfaces.
- Lower layers never know upper ones; they receive what they need from above.
- Each concern lives in the layer that owns it; app-wide concerns stay in the app.
- App follows MVVM (Flutter's official architecture guide): widgets render state and forward events; controllers / view models own UI flows; services and repositories do the I/O. Riverpod is thin glue, no codegen. Feature folders.
- One wiring point picks implementations; implementation-specific wiring lives in its own file.

## Interfaces
- Information hiding: an interface states the question, not how one implementation answers it. No parameters, types or concepts that only some implementations need.
- Encapsulate what varies: decisions that differ per sync tool or platform stay behind the interface; platform facts are injected into implementations at the wiring point.
- Sync-tool neutral: generic code works unchanged for any sync tool, including one without files on disk.
- One type, one meaning; prefer opaque ids and values over raw paths or mixed data.
- Pure units: a unit knows only its own job; mappings and policies have exactly one owner.
- Validate at the edge, with parse-only constructors.

## Robustness
- No dirty fixes, workarounds or caches to hide a design problem; if something doesn't fit, rethink the design.
- Expected failures are result values; exceptions are only for bugs.
- Never lose user data: if a save can't land, keep the content (e.g. as a conflict copy).
- Never silently recreate deleted files or folders.
- No automatic writes into synced folders; only user actions write there, so devices can't ping-pong.
- Byte-exact edits: change only what the user touched; never parse-and-reprint user files.
- Concurrency: reads that follow a write must see that write.

## Quality
- A trusted, maintained library beats own code; own code only where no trusted library fits these rules.
- Only well-trusted dependencies, pinned where normal (actions by commit SHA, SDKs by version, packages via lock files, wrappers by hash). Report where pinning isn't possible.
- Small files and units; split when a unit does two jobs.
- Every change ships with new or updated tests; every bug fix gets a test that fails without it.
- CI stays green; never skip or disable a test.
- Unit tests for core and controllers; UI tests for user flows.
- Adversarial self-review of the diff before asking for review.
