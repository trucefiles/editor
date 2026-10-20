import 'markup.dart';
import 'shown_text.dart';

/// How a block's Markdown marks show in an editor. Any editor can show
/// any style; the style decides, the editor only draws.
enum MarkStyle {
  /// Every mark shows, dimmed: all text as in the file.
  shown,

  /// Marks hide, except in the block being edited, which shows every
  /// character, so typing never touches a hidden mark.
  mixed;

  /// [source] with its [markup] as it shows in this style, in a block that
  /// is [edited] or not.
  ShownText show(
    String source,
    List<MarkupSpan> markup, {
    required bool edited,
  }) => switch (this) {
    shown => ShownText.asIs(source, markup),
    mixed when edited => ShownText.asIs(source, markup),
    mixed => ShownText.of(source, markup),
  };
}
