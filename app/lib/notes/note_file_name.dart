import 'dart:convert';

import 'package:characters/characters.dart';

/// Characters not allowed in file names on at least one platform.
final _unsafe = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

const _maxBaseLength = 80;

/// File names may hold 255 UTF-8 bytes. This leaves room for a number
/// (` 100`), `.md` and a sync tool's conflict-copy marker (Syncthing's
/// `.sync-conflict-20261003-134809-4I343AW` takes 38), so a conflict copy
/// of the note can always be written.
const _maxBaseBytes = 200;

/// File name for a new note titled [title], ending in [extension].
/// [attempt] counts up from 1 to make it unique: `Title.md`, `Title 2.md`, …
///
/// Leading dots (hidden files) and trailing dots and spaces (invalid on
/// Windows) are dropped.
String noteFileName(String title, {int attempt = 1, String extension = '.md'}) {
  var base = title
      .replaceAll(_unsafe, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(RegExp(r'^\.+'), '');
  base = _cut(base);
  base = base.replaceFirst(RegExp(r'[. ]+$'), '');
  if (base.isEmpty) base = 'Untitled';
  return attempt == 1 ? '$base$extension' : '$base $attempt$extension';
}

/// [text] cut to [_maxBaseLength] characters and [_maxBaseBytes] UTF-8
/// bytes, without splitting a character as the user sees it (e.g. an
/// emoji made of several code points).
String _cut(String text) {
  final kept = StringBuffer();
  var bytes = 0;
  for (final character in text.characters.take(_maxBaseLength)) {
    bytes += utf8.encode(character).length;
    if (bytes > _maxBaseBytes) break;
    kept.write(character);
  }
  return kept.toString();
}

/// [name] split before its extension's dot, e.g. `todo` and `.md`; a name
/// without one, or only a leading dot, has an empty extension.
({String base, String extension}) splitFileName(String name) {
  final dot = name.lastIndexOf('.');
  return dot > 0
      ? (base: name.substring(0, dot), extension: name.substring(dot))
      : (base: name, extension: '');
}

/// Whether the file [name] is what [noteFileName] gives for [title], with
/// any number added and in any case: renaming it would change nothing, or
/// only the case, which some storage (e.g. Android's) can't tell apart.
bool isNamedAfter(String name, String title) {
  final base = splitFileName(name).base.toLowerCase();
  final wanted = splitFileName(noteFileName(title)).base.toLowerCase();
  return base == wanted ||
      RegExp('^${RegExp.escape(wanted)} [0-9]+\$').hasMatch(base);
}
