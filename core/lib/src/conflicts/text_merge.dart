/// How one document type merges two texts of the same document into one,
/// e.g. a conflict copy into its main file, or edits into a file that
/// changed elsewhere. Pure: texts in, result out; knows no files.
/// Deterministic and idempotent: the same inputs give the same text on
/// every device, and merging a merged text again changes nothing.
abstract interface class TextMerge {
  /// [main] and [other] as one text, in [main]'s layout where they agree.
  /// [base]: the text [other] was edited from, if known; then only parts
  /// [other] changed from it count as lost when they lose.
  MergeResult merge(String main, String other, {String? base});
}

/// How a [TextMerge] went.
sealed class MergeResult {
  const MergeResult();
}

/// Both texts merged into [text]. [lost]: what of `other` lost to `main`,
/// named for the user (e.g. an event's title); empty when nothing did.
final class MergedText extends MergeResult {
  const MergedText(this.text, {this.lost = const []});

  final String text;
  final List<String> lost;
}

/// The texts can't be merged (e.g. one can't be read as the type); the
/// user compares them instead.
final class CantMerge extends MergeResult {
  const CantMerge();
}
