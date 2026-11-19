import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_file_page/truce_file_page.dart';

/// Keeps images in memory, named by count, and links them at once;
/// fails with [failWith]. Links of none are kept ([keptAt]).
final class FakeHostImages implements HostImages {
  final Map<String, Uint8List> kept = {};
  StoreError? failWith;

  @override
  RelPath? keptAt(String link) => null;

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
