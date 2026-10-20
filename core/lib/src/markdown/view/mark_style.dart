import '../syntax/markup.dart';
import '../syntax/shown_line.dart';

/// How a line's Markdown marks show in an editor. Any editor can show any
/// style; the style decides, the editor only draws.
enum MarkStyle {
  /// Every mark shows, dimmed: all text as in the file.
  shown,

  /// Marks hide, except on the lines being edited, which show every
  /// character, so typing never touches a hidden mark.
  mixed,

  /// Marks hide everywhere: formatted text only.
  hidden;

  /// [source] with its [markup] as it shows in this style, on a line that
  /// is [edited] or not.
  ShownLine show(
    String source,
    List<MarkupSpan> markup, {
    required bool edited,
  }) => switch (this) {
    shown => ShownLine.asIs(source, markup),
    mixed when edited => ShownLine.asIs(source, markup),
    mixed || hidden => ShownLine.of(source, markup),
  };
}
