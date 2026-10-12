import 'dart:convert';
import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import '../folders/folder_services.dart';

/// The two versions of one conflict copy, as text to compare.
final class ConflictSides {
  const ConflictSides({
    required this.copy,
    required this.current,
    required this.other,
  });

  /// The copy being resolved: the oldest one left.
  final ConflictCopy copy;

  /// The main file's text; `null` if it was deleted.
  final String? current;

  final String other;

  /// Reads both sides of [conflict]'s oldest copy.
  ///
  /// Text is decoded for display only; bytes that are not valid UTF-8
  /// show as replacement characters. Writing goes through
  /// [ConflictService.resolve], which uses the original bytes.
  static Future<Result<ConflictSides, StoreError>> load(
    FolderServices services,
    Conflict conflict,
  ) async {
    final copy = conflict.copies.first;
    final Uint8List other;
    switch (await services.conflicts.readCopy(copy)) {
      case Ok(:final value):
        other = value;
      case Err(:final error):
        return Err(error);
    }
    String? current;
    if (!conflict.isOrphaned) {
      switch (await services.store.read(conflict.mainPath)) {
        case Ok(:final value):
          current = _text(value.bytes);
        case Err(:final error):
          return Err(error);
      }
    }
    return Ok(ConflictSides(copy: copy, current: current, other: _text(other)));
  }

  static String _text(Uint8List bytes) =>
      utf8.decode(bytes, allowMalformed: true).replaceAll('\r\n', '\n');
}
