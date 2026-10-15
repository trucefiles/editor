import 'dart:convert';
import 'dart:io';

import 'package:truce_core/truce_core.dart';

/// A JSON value kept in one file in app storage, e.g. a setting. Writes
/// replace the file atomically, so a read never sees half of one.
final class JsonFile {
  const JsonFile(this._file);

  final File _file;

  /// The saved value.
  Future<Result<Object?, JsonFileError>> read() async {
    final String raw;
    try {
      if (!await _file.exists()) return const Err(JsonFileError.missing);
      raw = await _file.readAsString();
    } on FileSystemException {
      return const Err(JsonFileError.unreadable);
    }
    try {
      return Ok(jsonDecode(raw));
    } on FormatException {
      return const Err(JsonFileError.corrupt);
    }
  }

  /// Replaces the saved value with [json], via a temp file.
  Future<Result<void, JsonFileError>> write(Object? json) async {
    final temp = File('${_file.path}.tmp');
    try {
      await _file.parent.create(recursive: true);
      await temp.writeAsString(jsonEncode(json), flush: true);
      await temp.rename(_file.path);
      return const Ok(null);
    } on FileSystemException {
      return const Err(JsonFileError.unwritable);
    }
  }
}

enum JsonFileError {
  /// Nothing saved yet.
  missing,
  unreadable,
  corrupt,
  unwritable,
}
