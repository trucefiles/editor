/// Test doubles and helpers for code built on `truce_core`; for tests only.
///
/// The fake sync tool ([FakeSyncAdapter], [FakeConflictSource]) lets
/// generic code be tested without any real sync tool.
library;

export 'src/testing/fake_conflict_source.dart';
export 'src/testing/fake_sync_adapter.dart';
export 'src/testing/memory_file_store.dart';
export 'src/testing/test_helpers.dart';
