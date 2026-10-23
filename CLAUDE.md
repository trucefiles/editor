# Coding standards

Clean layered design, KISS, Single Responsibility, standard practice.
Clean separation between layers and responsibilities is the biggest concern.
Prefer the simpler option when in doubt.

## Architecture
- `core` is pure Dart with no UI; `app` is a thin Flutter layer that uses only core's public interfaces.
- Each sync tool's conventions live in a pure-Dart package of their own (`syncthing`); `core` never knows one, and in the app only the sync-tool wiring imports it.
- Lower layers never know upper ones; they receive what they need from above.
- Each concern lives in the layer that owns it; app-wide concerns stay in the app.
- App follows MVVM (Flutter's official architecture guide): widgets render state and forward events; controllers / view models own UI flows; services and repositories do the I/O. Riverpod is thin glue, no codegen. Feature folders.
- One wiring point picks implementations; implementation-specific wiring lives in its own file.
- Platforms are told apart only in `app/lib/platform/platform_wiring.dart`; platform-specific code lives in `platform/<os>/` (e.g. `linux/`, `android/`), and everything else gets platform facts injected.
- App-private storage (settings, drafts, backups) is never synced, so it never follows a sync tool's rules (temp names, ignored files).

## Interfaces
- Information hiding: an interface states the question, not how one implementation answers it. No parameters, types or concepts that only some implementations need.
- Encapsulate what varies: decisions that differ per sync tool or platform stay behind the interface; platform facts are injected into implementations at the wiring point.
- Sync-tool neutral: generic code works unchanged for any sync tool, including one without files on disk.
- One type, one meaning; prefer opaque ids and values over raw paths or mixed data.
- Pure units: a unit knows only its own job; mappings and policies have exactly one owner.
- Validate at the edge, with parse-only constructors.

## Code style
- Best design first: model the domain with the right entities and abstractions, then code it; never a quick version, or one shaped after old code, to clean up later.
- Declarative over procedural: say what a value is (collection literals and comprehensions, `map`/`where`/`fold`, `switch` expressions with patterns, `package:collection` helpers), not how to build it step by step. No index loops, counters or flags where a declarative form reads as well.
- Functional where possible: pure functions and immutable values; structure is derived once in an entity (e.g. a parsed tree) and questions are lookups on it, never rescans.
- Object-oriented where state or identity is real: an entity owns its data and the rules on it; closed sets of cases are sealed classes, matched exhaustively.
- Mutation only where it is the job (a session, an editor bridge), inside one owner. A loop with local state only where it is the clearest form (e.g. a single-pass parser).
- One rule, one place: logic two operations share is one helper, never two variants.
- Names in the domain's words; doc comments state the contract, not the steps.
- Best behavior, not legacy: existing behavior is no standard to keep. When a better or more correct behavior exists (for users, for the code, for efficiency), propose it with its user-visible impact and switch to it once agreed; compare with old code only to find the differences, never to copy its quirks.

## Robustness
- Restructure, never bolt on: when something doesn't fit (a new requirement, an abstraction of our own or a library's that only allows a shortcut), change or improve the design in the same change, even if that makes it larger. No dirty fixes, workarounds or caches to hide a design problem. Name the restructure in the plan, so its size is agreed up front. Structure and design stay healthy with every change.
- Expected failures are result values; exceptions are only for bugs.
- Never lose user data: if a save can't land, keep the content (e.g. as a conflict copy).
- Never silently recreate deleted files or folders. Accepted exceptions are listed in `docs/known-limitations.md`.
- No automatic writes into synced folders; only user actions write there, so devices can't ping-pong. Finishing a user's own write later is allowed (pending edits written at the next start, the same bytes rewritten once so the sync tool sees them): it is never caused by a remote change.
- Byte-exact edits: change only what the user touched; never parse-and-reprint user files.
- Edits say what, one writer says how: an edit states the new structure (text, kind, checked, level, position) and never builds file text; one writer per kind of line turns that into bytes, keeping each line's own style. New editing features (headings, quotes, tables) follow the same shape.
- Concurrency: reads that follow a write must see that write.

## Quality
- A trusted, maintained library beats own code; own code only where no trusted library fits these rules.
- Only well-trusted dependencies, pinned where normal (actions by commit SHA, SDKs by version, packages via lock files, wrappers by hash). Report where pinning isn't possible.
- Small files and units; split when a unit does two jobs.
- Every change ships with new or updated tests; every bug fix gets a test that fails without it.
- CI stays green; never skip or disable a test.
- Unit tests for core and controllers; UI tests for user flows.
- Changes that affect how the UI looks (layout, theme, visuals; not animations or behavior) are also checked with a few screenshots, at least locally (e.g. a UI test on Linux saving the view's layer as PNG), on desktop and touch looks and at a larger text size where it matters.
- Generic code is tested in its own package against fakes (e.g. a fake sync tool); each implementation tests the same flows on its real code.
- Shared test doubles live in the test-only `test_support` package, never in a production `lib`.
- Structural refactors change no behavior unless a better one is agreed (see Best behavior): the existing tests are the guard and keep their checks; move files with `git mv` instead of rewriting them.
- Adversarial self-review of the diff before asking for review.
