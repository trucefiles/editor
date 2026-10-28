import 'package:truce_core/truce_core.dart';

/// A made-up document type for tests of generic code: its files end in
/// `.md`; its title is a first line starting with `# `, and its preview
/// the other lines, the first [FakePreview.lines] of them.
final class FakeFileType implements FileTypeSupport<FakePreview> {
  const FakeFileType();

  static const id = FileType('fake');

  @override
  FileType get type => id;

  @override
  Set<String> get extensions => const {'md'};

  @override
  TextSummary<FakePreview> summary(String text, {required int maxLines}) =>
      _FakeSummary(text, maxLines);
}

/// How a fake preview shows: [lines] at most.
final class FakePreview {
  const FakePreview({this.lines});

  final int? lines;
}

final class _FakeSummary implements TextSummary<FakePreview> {
  _FakeSummary(String text, this._maxLines) : _lines = text.split('\n');

  final List<String> _lines;
  final int _maxLines;

  @override
  String? get title =>
      _lines.first.startsWith('# ') ? _lines.first.substring(2) : null;

  @override
  String get firstLine => _lines
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');

  @override
  String preview(FakePreview options) => _lines
      .skip(title == null ? 0 : 1)
      .take(options.lines ?? _maxLines)
      .join('\n');
}

/// Detects the fake document type ([FakeFileType]).
const fakeFileTypes = ExtensionFileTypeDetector({'md': FakeFileType.id});
