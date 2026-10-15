import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

/// Edits to one note, kept on this device until they are in the note's
/// file.
@immutable
final class NoteDraft {
  const NoteDraft({
    required this.id,
    required this.path,
    required this.base,
    required this.text,
  });

  /// Random, so any note path fits; names the draft in its store.
  final String id;

  /// The note's file in its folder.
  final RelPath path;

  /// The file's text the edits started from: if the file still holds it,
  /// the edits can go into the file.
  final String base;

  /// The edited text.
  final String text;

  static final _random = Random.secure();

  static String newId() =>
      List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

  Map<String, Object> toJson() => {
    'path': path.value,
    'base': base,
    'text': text,
  };

  /// `null` if [json] is not a draft written by [toJson].
  static NoteDraft? fromJson(String id, Object? json) => switch (json) {
    {
      'path': final String raw,
      'base': final String base,
      'text': final String text,
    } =>
      switch (RelPath.parse(raw)) {
        final path? => NoteDraft(id: id, path: path, base: base, text: text),
        null => null,
      },
    _ => null,
  };
}
