import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../storage/json_file.dart';
import 'text_zoom.dart';

/// Keeps one text zoom in a JSON file in app storage. Per
/// device. [TextZoom.normal] unless the user chose another; read and
/// write failures fall back to that.
final class TextZoomStore {
  TextZoomStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  static const _key = 'percent';

  /// The saved zoom; [TextZoom.normal] if none or unreadable.
  Future<TextZoom> load() async => switch (await _file.read()) {
    Ok(value: {_key: final percent}) =>
      TextZoom.fromJson(percent) ?? TextZoom.normal,
    _ => TextZoom.normal,
  };

  /// Replaces the saved zoom; on failure it stays as it is for this run.
  Future<void> save(TextZoom zoom) => _file.write({_key: zoom.toJson()});
}
