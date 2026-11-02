/// How the printer writes a link: in its source style while that still
/// reads as the same link, else as an inline link.
library;

import 'package:collection/collection.dart';

import '../read/syntax/characters.dart';
import '../read/syntax/extended_autolinks.dart';
import '../read/syntax/link_syntax.dart';
import '../tree/blocks.dart';
import '../tree/inlines.dart';
import '../visible/formatting.dart';
import 'char_classes.dart';
import 'escaping.dart';
import 'inline_cells.dart';

/// How a link is written.
enum LinkForm {
  /// `[text](destination "title")`.
  inline,

  /// `[text][label]`, `[text][]` or `[text]`.
  reference,

  /// `<destination>`.
  angle,

  /// A bare url or email address.
  bare;

  /// Whether its text is written between brackets, where it can have
  /// formats of its own.
  bool get bracketed => this == inline || this == reference;

  /// The class of the first character it prints, its text's [first] if
  /// bare.
  CharClass startClass(CharClass first) =>
      this == bare ? first : CharClass.punctuation;

  /// The class of the last character it prints, its text's [last] if
  /// bare.
  CharClass endClass(CharClass last) =>
      this == bare ? last : CharClass.punctuation;
}

/// How [link] is written between text that prints as [before] and
/// [after] (as plain characters): in the style it was written in while
/// that reads as the same link with [definitions], else inline.
LinkForm linkFormOf(
  LinkElement link, {
  required String before,
  required String after,
  required Map<String, LinkDefinition> definitions,
}) {
  final mark = link.link;
  final text = link.cells.every((cell) => cell is CharCell)
      ? link.cells.map((cell) => (cell as CharCell).char).join()
      : null;
  return switch (mark.style) {
    LinkStyle.reference
        when mark.read != null && linkResolves(mark, definitions) =>
      LinkForm.reference,
    LinkStyle.autolink
        when text != null && autolinkDestination(text) == mark.destination =>
      LinkForm.angle,
    LinkStyle.extendedAutolink
        when text != null &&
            _bareText.hasMatch(text) &&
            _readsBare(before, text, after, mark.destination) =>
      LinkForm.bare,
    _ => LinkForm.inline,
  };
}

/// Whether [link], if read as a reference, still reads as itself with
/// [definitions].
bool linkResolves(LinkMark link, Map<String, LinkDefinition> definitions) =>
    switch (link.read) {
      final read? when link.style == LinkStyle.reference => _resolves(
        referenceLabel(read),
        link.destination,
        link.title,
        definitions,
      ),
      _ => true,
    };

/// Whether [image], if read as a reference, still reads as itself with
/// [definitions].
bool imageResolves(
  ImageInline image,
  Map<String, LinkDefinition> definitions,
) =>
    !image.close.endsWith(']') ||
    _resolves(
      referenceLabel(image),
      image.destination,
      image.title,
      definitions,
    );

/// [image] as written: as read while that reads as itself with
/// [definitions], else inline.
String imageSource(ImageInline image, Map<String, LinkDefinition> definitions) {
  if (imageResolves(image, definitions)) return image.source;
  final description = image.children.map((child) => child.source).join();
  return '![$description](${destinationSource(image.destination)}'
      '${titleSource(image.title)})';
}

bool _resolves(
  String label,
  String destination,
  String title,
  Map<String, LinkDefinition> definitions,
) => switch (definitions[normalizeLabel(label)]) {
  (destination: final found, title: final foundTitle, label: _) =>
    found == destination && (foundTitle ?? '') == title,
  null => false,
};

/// Whether a bare link's [text] reads as a link to [destination] between
/// [before] and [after], also at a line's start.
bool _readsBare(String before, String text, String after, String destination) {
  // Marks after the link end a reader's text where they print; an `&`
  // there could make the link end apart from them.
  final next = after.split(_whitespace).first;
  if (next.contains('&')) return false;
  final context = '$before$text$after';
  final start = before.length;
  // From its word's start: text before it could read as a link with it.
  final wordStart = before.lastIndexOf(_whitespace) + 1;
  // Starting a word, it can start a line, where an escape would cut it.
  if (wordStart == start && lineStartEscaped(text) != text) return false;
  return switch (findExtendedAutolinks(
    context,
    wordStart,
    context.length,
  ).firstWhereOrNull((link) => link.end > start)) {
    (start: final found, :final end, destination: final reads) =>
      found == start && end == start + text.length && reads == destination,
    null => false,
  };
}

/// Text a bare link can have: nothing a writer escapes or a reader takes
/// as a mark (an `_` only inside a word, an `&` that reads as itself).
final _bareText = RegExp(
  r'^(?:[^\\`*~\[\]<>!&_\s]|(?<=[A-Za-z0-9])_(?=[A-Za-z0-9])|&(?![A-Za-z0-9#]+;))+$',
);

/// [destination] as an inline link writes it: as is where it reads as
/// is, else between `<` and `>`.
String destinationSource(String destination) {
  final escaped = destination.replaceAllMapped(
    _escapeNeeded,
    (match) => '\\${match[0]}',
  );
  return _plainDestination.hasMatch(destination) && _balanced(destination)
      ? escaped
      : '<${escaped.replaceAll('<', r'\<').replaceAll('>', r'\>')}>';
}

/// A link title as written after its destination; empty for none.
String titleSource(String title) {
  if (title.isEmpty) return '';
  final escaped = title
      .replaceAllMapped(_escapeNeeded, (match) => '\\${match[0]}')
      .replaceAll('\n', '&#10;');
  if (!title.contains('"')) return ' "$escaped"';
  if (!title.contains("'")) return " '$escaped'";
  return ' "${escaped.replaceAll('"', r'\"')}"';
}

/// A backslash before punctuation or at the end (before the closing
/// mark), and an `&`, would read as escapes and references.
final _escapeNeeded = RegExp(
  r'''\\(?=[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]|$)|&''',
);

final _whitespace = RegExp(r'\s');

final _plainDestination = RegExp(r'^[^\x00-\x20\x7f<>]+$');

bool _balanced(String text) =>
    text
        .split('')
        .fold<int?>(
          0,
          (depth, char) => switch ((depth, char)) {
            (null, _) => null,
            (final depth?, '(') => depth + 1,
            (0, ')') => null,
            (final depth?, ')') => depth - 1,
            (final depth?, _) => depth,
          },
        ) ==
    0;
