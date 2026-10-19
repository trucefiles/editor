import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// A [LocalFileStore] on a fresh temp folder, deleted after the test.
final class StoreFolder {
  StoreFolder._(this.root)
    : store = LocalFileStore(root.path, (token) => '.tmp-$token');

  static Future<StoreFolder> create() async {
    final root = await Directory.systemTemp.createTemp('truce_store_test');
    addTearDown(() async {
      // Some tests remove the root.
      if (await root.exists()) await root.delete(recursive: true);
    });
    return StoreFolder._(root);
  }

  final Directory root;
  final LocalFileStore store;

  Future<void> write(String relPath, String text) async {
    final file = File('${root.path}/$relPath');
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  String? textAt(String relPath) {
    final file = File('${root.path}/$relPath');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  Future<FileVersion> versionOf(String relPath) async =>
      (await store.read(path(relPath))).value.version;

  /// The names of what the root holds.
  List<String> names() => [
    for (final entry in root.listSync()) entry.uri.pathSegments.last,
  ];

  /// Writes `old` to [relPath], reads it, and changes it elsewhere; returns
  /// the version read.
  Future<FileVersion> changedSinceRead(String relPath) async {
    await write(relPath, 'old');
    final version = await versionOf(relPath);
    await write(relPath, 'changed elsewhere');
    return version;
  }

  /// Writes `old` to [relPath], reads it, and deletes it elsewhere; returns
  /// the version read.
  Future<FileVersion> deletedSinceRead(String relPath) async {
    await write(relPath, 'old');
    final version = await versionOf(relPath);
    await File('${root.path}/$relPath').delete();
    return version;
  }
}
