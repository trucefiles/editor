import 'dart:convert';
import 'dart:io';

import 'package:pool/pool.dart';
import '../common/result.dart';

/// A JSON value kept in one file in app storage, e.g. a setting; one
/// [JsonFile] per file. Its writes run one at a time (see
/// [writeJsonAtomically]), and a read waits for the writes before it.
final class JsonFile {
  JsonFile(this._file);

  final File _file;
  final _writes = Pool(1);

  /// The saved value.
  Future<Result<Object?, JsonFileError>> read() async {
    await _writes.withResource(() async {});
    return readJson(_file);
  }

  /// Replaces the saved value with [json], after every earlier write to
  /// the file.
  Future<Result<void, JsonFileError>> write(Object? json) =>
      _writes.withResource(() => writeJsonAtomically(_file, json));
}

/// The JSON value saved in [file].
Future<Result<Object?, JsonFileError>> readJson(File file) async {
  final String raw;
  try {
    if (!await file.exists()) return const Err(JsonFileError.missing);
    raw = await file.readAsString();
  } on FileSystemException {
    return const Err(JsonFileError.unreadable);
  }
  try {
    return Ok(jsonDecode(raw));
  } on FormatException {
    return const Err(JsonFileError.corrupt);
  }
}

/// Replaces what [file] holds with [json] via a temp file, so a read never
/// sees half of it. Writes of one file must not overlap: they would share
/// the temp file.
Future<Result<void, JsonFileError>> writeJsonAtomically(
  File file,
  Object? json,
) async {
  final temp = File('${file.path}.tmp');
  try {
    await file.parent.create(recursive: true);
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(file.path);
    return const Ok(null);
  } on FileSystemException {
    return const Err(JsonFileError.unwritable);
  }
}

enum JsonFileError {
  /// Nothing saved yet.
  missing,
  unreadable,
  corrupt,
  unwritable,
}
