import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

/// Edits to one note, kept on this device until they are in the note's
/// file; for a new note, until its file is created.
@immutable
final class NoteDraft {
  const NoteDraft({
    required this.id,
    required this.path,
    required this.text,
    this.base,
  });

  /// Random, so any note path fits; names the draft in its store.
  final String id;

  /// The note's file in its folder; for a new note, where its file goes,
  /// with a number added if the name is taken.
  final RelPath path;

  /// The file's text the edits started from: if the file still holds it,
  /// the edits can go into the file. `null` for a new note: it has no
  /// file yet.
  final String? base;

  /// The edited text.
  final String text;

  static final _random = Random.secure();

  static String newId() =>
      List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

  Map<String, Object> toJson() => {
    'path': path.value,
    'base': ?base,
    'text': text,
  };

  /// `null` if [json] is not a draft written by [toJson].
  static NoteDraft? fromJson(String id, Object? json) => switch (json) {
    {
      'path': final String raw,
      'base': final String? base,
      'text': final String text,
    } =>
      _parsed(id, raw, base, text),
    {'path': final String raw, 'text': final String text} => _parsed(
      id,
      raw,
      null,
      text,
    ),
    _ => null,
  };

  static NoteDraft? _parsed(String id, String raw, String? base, String text) =>
      switch (RelPath.parse(raw)) {
        final path? => NoteDraft(id: id, path: path, base: base, text: text),
        null => null,
      };
}
