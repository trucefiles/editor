import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/truce_document_editor.dart';

/// Keeps images in memory, named by count, and links them at once;
/// fails with [failWith].
final class FakeImageKeeping implements ImageKeeping {
  final Map<String, Uint8List> kept = {};
  StoreError? failWith;

  @override
  Future<Result<void, StoreError>> add(
    Uint8List bytes, {
    required String extension,
    required void Function(String link) insert,
  }) async {
    if (failWith case final error?) return Err(error);
    final link = 'kept/${kept.length + 1}.$extension';
    kept[link] = bytes;
    insert(link);
    return const Ok(null);
  }
}
