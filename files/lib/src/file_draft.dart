import 'dart:math';

import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

/// Edits to one file, kept on this device until they are in the file's
/// file; for a new file, until its file is created.
@immutable
final class FileDraft {
  const FileDraft({
    required this.id,
    required this.path,
    required this.text,
    this.base,
    this.newSubfolder = false,
  });

  /// Random, so any file path fits; names the draft in its store.
  final String id;

  /// The file in its folder; for a new file, where its file goes,
  /// with a number added if the name is taken.
  final RelPath path;

  /// The file's text the edits started from: if the file still holds it,
  /// the edits can go into the file. `null` for a new file: it has no
  /// file yet.
  final String? base;

  /// The edited text.
  final String text;

  /// For a new file: [path]'s folder is a new subfolder the user asked
  /// for, made right before the file.
  final bool newSubfolder;

  static final _random = Random.secure();

  static String newId() =>
      List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

  Map<String, Object> toJson() => {
    'path': path.value,
    'base': ?base,
    'text': text,
    if (newSubfolder) 'newSubfolder': true,
  };

  /// `null` if [json] is not a draft written by [toJson].
  static FileDraft? fromJson(String id, Object? json) => switch (json) {
    {'path': final String raw, 'text': final String text} => switch ((
      RelPath.parse(raw),
      json['base'],
    )) {
      (final path?, final String? base) => FileDraft(
        id: id,
        path: path,
        base: base,
        text: text,
        // An optional field: anything but `true` reads as its default, so
        // it never makes the draft unreadable.
        newSubfolder: json['newSubfolder'] == true,
      ),
      _ => null,
    },
    _ => null,
  };
}
