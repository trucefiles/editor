import 'dart:typed_data';

import 'package:truce_files/truce_files.dart';

import '../text/text_file.dart';
import '../text/text_merge.dart';

/// A text type's [TextMerge] on the files' bytes: both decoded, merged
/// as text, written in the main file's byte style.
final class TextBytesMerge implements FileMerge {
  const TextBytesMerge(this._merge);

  final TextMerge _merge;

  /// `null` also if either is no text.
  @override
  MergedSides? merge(Uint8List current, Uint8List other) {
    final (main, copy) = (TextFile.decode(current), TextFile.decode(other));
    if (main == null || copy == null) return null;
    return switch (_merge.merge(main.text, copy.text)) {
      MergedText(:final text, :final lost) => (
        bytes: main.encode(text),
        lost: lost,
      ),
      CantMerge() => null,
    };
  }
}
