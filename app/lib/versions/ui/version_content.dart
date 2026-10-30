/// What a version shown for comparison holds.
sealed class VersionContent {
  const VersionContent();

  /// `null` for a deleted file.
  String? get text;
}

/// A file's text as it was saved at [modified].
final class SavedText extends VersionContent {
  const SavedText(this.text, this.modified);

  @override
  final String text;

  final DateTime modified;
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
