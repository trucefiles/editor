/// Test doubles and helpers for tests of code built on `truce_core`.
///
/// The fake sync tool ([FakeSyncAdapter], [FakeConflictSource]) lets
/// generic code be tested without any real sync tool; the fake document
/// type ([FakeFileType]) without any real file type.
library;

export 'src/fake_conflict_source.dart';
export 'src/fake_copy_names.dart';
export 'src/fake_file_type.dart';
export 'src/fake_folder_markers.dart';
export 'src/fake_sync_adapter.dart';
export 'src/machine_run.dart';
export 'src/manual_timers.dart';
export 'src/memory_file_store.dart';
export 'src/spy_file_store.dart';
export 'src/test_helpers.dart';
