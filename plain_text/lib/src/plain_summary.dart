import 'package:truce_core/truce_core.dart';

/// What lists show of a plain text: its first line with words as the
/// title, and the lines with words after it as the preview, as written.
/// Each part is worked out when first asked.
final class PlainSummary implements TextSummary<PlainPreview> {
  PlainSummary(this._text, {required this.maxLines});

  final String _text;

  /// The most lines a preview holds.
  final int maxLines;

  /// The lines with words, without spaces at their ends.
  late final List<String> _lines = [
    for (final line in splitLines(_text))
      if (line.text.trim().isNotEmpty) line.text.trimRight(),
  ];

  @override
  late final String firstLine = _lines.firstOrNull?.trim() ?? '';

  @override
  String? get title => firstLine.isEmpty ? null : firstLine;

  /// Up to [maxLines] lines with words after the title.
  @override
  String preview(PlainPreview options) => _preview;

  late final String _preview = _lines.skip(1).take(maxLines).join('\n');
}

/// How a plain text preview shows: always the same.
final class PlainPreview {
  const PlainPreview();
}
