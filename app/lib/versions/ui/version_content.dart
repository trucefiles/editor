import 'dart:typed_data';

import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

/// What a version shown for comparison holds.
sealed class VersionContent {
  const VersionContent();

  /// The text to compare with; `null` for a version without one (a
  /// deleted file, a picture).
  String? get text;
}

/// A file's text as it was saved at [modified].
final class SavedText extends VersionContent {
  const SavedText(this.text, this.modified);

  @override
  final String text;

  final DateTime modified;
}

/// A file as its [type] shows it whole (e.g. a picture), as it was
/// saved at [modified].
final class SavedView extends VersionContent {
  const SavedView(this.content, this.modified, {required this.type});

  final ShownContent content;
  final DateTime modified;
  final ViewType type;

  @override
  String? get text => null;
}

/// The open editor's text now, saved or not.
final class EditorText extends VersionContent {
  const EditorText(this.text);

  @override
  final String text;
}

/// A file that was deleted.
final class DeletedFile extends VersionContent {
  const DeletedFile();

  @override
  String? get text => null;
}

/// [bytes], a version of a file of [type] saved at [modified], as its
/// type shows it: whole on the view page's types, else as text.
VersionContent savedVersion(
  FilePageType? type,
  Uint8List bytes,
  DateTime modified,
) => switch (type) {
  final ViewType type => SavedView(
    ShownContent(bytes, () async => bytes),
    modified,
    type: type,
  ),
  EditableType() || null => SavedText(versionText(bytes), modified),
};
