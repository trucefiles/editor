import 'package:collection/collection.dart';

import '../tree/inlines.dart';

/// The formats visible text can have.
enum TextFormat { strong, emphasis, strike, code }

/// A link visible text shows. One link is one object: every piece of
/// its text holds the same mark.
final class LinkMark {
  LinkMark({
    required this.destination,
    required this.style,
    this.title = '',
    this.read,
  });

  /// The mark of the link [read] from a note.
  LinkMark.of(LinkInline this.read)
    : destination = read.destination,
      title = read.title,
      style = read.style;

  final String destination;
  final String title;
  final LinkStyle style;

  /// The link it was read as, whose spelling a writer keeps; `null` for
  /// a new link.
  final LinkInline? read;

  /// Whether it leads where [other] does, written the same way.
  bool looksLike(LinkMark other) =>
      other.destination == destination &&
      other.title == title &&
      other.style == style;

  @override
  String toString() => 'LinkMark($destination, ${style.name})';
}

/// How a piece of visible text is formatted: its formats and the link it
/// is part of.
final class Formatting {
  Formatting([Set<TextFormat> formats = const {}, this.link])
    : formats = Set.unmodifiable(formats);

  static final plain = Formatting();

  final Set<TextFormat> formats;
  final LinkMark? link;

  bool has(TextFormat format) => formats.contains(format);

  Formatting withFormat(TextFormat format, {required bool on}) => Formatting(
    on ? {...formats, format} : formats.difference({format}),
    link,
  );

  Formatting withLink(LinkMark? link) => Formatting(formats, link);

  /// Whether it formats as [other] does, also if its link is another one
  /// of the same look.
  bool looksLike(Formatting other) =>
      const SetEquality<TextFormat>().equals(other.formats, formats) &&
      switch ((link, other.link)) {
        (null, null) => true,
        (final LinkMark a?, final LinkMark b?) => a.looksLike(b),
        _ => false,
      };

  @override
  bool operator ==(Object other) =>
      other is Formatting &&
      identical(other.link, link) &&
      const SetEquality<TextFormat>().equals(other.formats, formats);

  @override
  int get hashCode => Object.hash(
    const SetEquality<TextFormat>().hash(formats),
    identityHashCode(link),
  );

  @override
  String toString() =>
      'Formatting(${formats.map((format) => format.name).join(',')}'
      '${link == null ? '' : ' $link'})';
}
