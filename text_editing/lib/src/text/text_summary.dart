/// What lists show of one text: its title, and a preview of its first
/// lines as plain words. Each part is worked out when first asked.
/// [Options] say how a preview shows, the type's own way (e.g. whether
/// checked items show).
abstract interface class TextSummary<Options> {
  /// The text's own title; `null` if it has none (the file name is used).
  String? get title;

  /// The name a new file of this text gets, as plain words: its first
  /// line with words, or what the type names it by otherwise (e.g. a
  /// calendar by its kind); empty if none.
  String get firstLine;

  /// The lines after the title, shown as [options] say.
  String preview(Options options);
}
