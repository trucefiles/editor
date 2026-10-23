import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../../storage/json_file.dart';
import 'note_text_size.dart';

/// Keeps how large notes' text shows in a JSON file in app storage. Per
/// device. [NoteTextSize.normal] unless the user chose another; read and
/// write failures fall back to that.
final class NoteTextSizeStore {
  NoteTextSizeStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  static const _key = 'percent';

  /// The saved size; [NoteTextSize.normal] if none or unreadable.
  Future<NoteTextSize> load() async => switch (await _file.read()) {
    Ok(value: {_key: final percent}) =>
      NoteTextSize.fromJson(percent) ?? NoteTextSize.normal,
    _ => NoteTextSize.normal,
  };

  /// Replaces the saved size; on failure it stays as it is for this run.
  Future<void> save(NoteTextSize size) => _file.write({_key: size.toJson()});
}
