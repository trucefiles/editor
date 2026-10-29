import 'dart:math';

import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

/// Edits to one document, kept on this device until they are in the document's
/// file; for a new document, until its file is created.
@immutable
final class DocumentDraft {
  const DocumentDraft({
    required this.id,
    required this.path,
    required this.text,
    this.base,
    this.newSubfolder = false,
  });

  /// Random, so any document path fits; names the draft in its store.
  final String id;

  /// The document's file in its folder; for a new document, where its file goes,
  /// with a number added if the name is taken.
  final RelPath path;

  /// The file's text the edits started from: if the file still holds it,
  /// the edits can go into the file. `null` for a new document: it has no
  /// file yet.
  final String? base;

  /// The edited text.
  final String text;

  /// For a new document: [path]'s folder is a new subfolder the user asked
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
  static DocumentDraft? fromJson(String id, Object? json) => switch (json) {
    {'path': final String raw, 'text': final String text} => switch ((
      RelPath.parse(raw),
      json['base'],
      json['newSubfolder'] ?? false,
    )) {
      (final path?, final String? base, final bool newSubfolder) =>
        DocumentDraft(
          id: id,
          path: path,
          base: base,
          text: text,
          newSubfolder: newSubfolder,
        ),
      _ => null,
    },
    _ => null,
  };
}
