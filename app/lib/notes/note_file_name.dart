/// Characters not allowed in file names on at least one platform.
final _unsafe = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

const _maxBaseLength = 80;

/// File name for a new note titled [title]. [attempt] counts up from 1 to
/// make it unique: `Title.md`, `Title 2.md`, …
///
/// Leading dots (hidden files) and trailing dots and spaces (invalid on
/// Windows) are dropped.
String noteFileName(String title, {int attempt = 1}) {
  var base = title
      .replaceAll(_unsafe, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(RegExp(r'^\.+'), '');
  base = String.fromCharCodes(base.runes.take(_maxBaseLength));
  base = base.replaceFirst(RegExp(r'[. ]+$'), '');
  if (base.isEmpty) base = 'Untitled';
  return attempt == 1 ? '$base.md' : '$base $attempt.md';
}
