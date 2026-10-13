import 'dart:convert';

/// Characters not allowed in file names on at least one platform.
final _unsafe = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

const _maxBaseLength = 80;

/// File names may hold 255 UTF-8 bytes. This leaves room for a number
/// (` 100`), `.md` and a sync tool's conflict-copy marker (Syncthing's
/// `.sync-conflict-20261003-134809-4I343AW` takes 38), so a conflict copy
/// of the note can always be written.
const _maxBaseBytes = 200;

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
  base = _cut(base);
  base = base.replaceFirst(RegExp(r'[. ]+$'), '');
  if (base.isEmpty) base = 'Untitled';
  return attempt == 1 ? '$base.md' : '$base $attempt.md';
}

/// [text] cut to [_maxBaseLength] characters and [_maxBaseBytes] UTF-8
/// bytes, without splitting a character.
String _cut(String text) {
  final kept = <int>[];
  var bytes = 0;
  for (final rune in text.runes.take(_maxBaseLength)) {
    bytes += utf8.encode(String.fromCharCode(rune)).length;
    if (bytes > _maxBaseBytes) break;
    kept.add(rune);
  }
  return String.fromCharCodes(kept);
}
