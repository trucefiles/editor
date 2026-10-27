/// Test doubles and helpers for tests of code built on `truce_core`.
///
/// The fake sync tool ([FakeSyncAdapter], [FakeConflictSource]) lets
/// generic code be tested without any real sync tool.
library;

export 'src/fake_conflict_source.dart';
export 'src/fake_sync_adapter.dart';
export 'src/machine_run.dart';
export 'src/manual_timers.dart';
export 'src/memory_file_store.dart';
export 'src/test_helpers.dart';
