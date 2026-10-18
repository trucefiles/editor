import 'dart:convert';
import 'dart:io';

import 'package:pool/pool.dart';
import 'package:truce_core/truce_core.dart';

/// A JSON value kept in one file in app storage, e.g. a setting; one
/// [JsonFile] per file. Writes replace the file atomically, so a read
/// never sees half of one; they run one at a time, so they never share a
/// temp file, and a read waits for the writes before it.
final class JsonFile {
  JsonFile(this._file);

  final File _file;
  final _writes = Pool(1);

  /// The saved value.
  Future<Result<Object?, JsonFileError>> read() async {
    await _writes.withResource(() async {});
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

  /// Replaces the saved value with [json], via a temp file, after every
  /// earlier write to the file.
  Future<Result<void, JsonFileError>> write(Object? json) =>
      _writes.withResource(() => _writeNow(json));

  /// Removes the saved value, after every earlier write; nothing saved is
  /// fine.
  Future<Result<void, JsonFileError>> delete() =>
      _writes.withResource(() async {
        try {
          if (await _file.exists()) await _file.delete();
          return const Ok(null);
        } on FileSystemException {
          return const Err(JsonFileError.unwritable);
        }
      });

  Future<Result<void, JsonFileError>> _writeNow(Object? json) async {
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
