/// The lines a text, heading or code leaf prints anew as, after its
/// containers' marks.
library;

import 'package:collection/collection.dart';

import '../doc/doc_nodes.dart';
import '../tree/blocks.dart';
import 'escaping.dart';
import 'inline_printer.dart';
import 'print_style.dart';
import 'text_layouts.dart';
import 'wrapping.dart';

/// [node]'s text in lines, laid out by [layouts], wrapped as its source
/// was, after marks [firstPrefix] (first line) and [restPrefix] wide.
List<String> textLines(
  TextNode node,
  TextLayouts layouts, {
  required int firstPrefix,
  required int restPrefix,
}) {
  final source = switch (node.source) {
    HeadingBlock(:final lines) => lines.sublist(0, lines.length - 1),
    ParagraphBlock(:final lines) => lines,
    _ => null,
  };
  return wrappedLines(
    printInline(layouts.of(node), hardBreak: hardBreakOf(node.source)),
    firstPrefix: firstPrefix,
    restPrefix: restPrefix,
    source: source == null
        ? null
        : (
            contents: [for (final line in source) line.content],
            widths: [for (final line in source) line.text.length],
          ),
  );
}

/// [heading] as an ATX heading line: `#`s and its text in one line.
String atxHeading(HeadingNode heading, TextLayouts layouts) {
  final content = headingEndEscaped(
    printInline(layouts.of(heading), hardBreak: r'\')
        .map(
          (token) => switch (token) {
            WordToken(:final source) => source,
            _ => ' ',
          },
        )
        .join(),
  );
  return '${'#' * heading.level}${content.isEmpty ? '' : ' $content'}';
}

/// Whether [heading] prints as a setext heading: it was read as one, of
/// a level it can have, and has text.
bool isSetext(HeadingNode heading) =>
    heading.level <= 2 &&
    !heading.text.isEmpty &&
    heading.source is HeadingBlock &&
    (heading.source! as HeadingBlock).style == HeadingStyle.setext;

/// The underline of [heading], a setext heading: as read, else written
/// for its level.
String underlineOf(HeadingNode heading) {
  final source = heading.source! as HeadingBlock;
  final underline = source.lines.last.content.trimRight();
  if (source.level == heading.level) return underline;
  return (heading.level == 1 ? '=' : '-') *
      (underline.length < 3 ? 3 : underline.length);
}

/// [code]'s lines: [indented] by four spaces, else between fences as
/// read (or ```), long enough that no line closes them.
List<String> codeLines(CodeNode code, {required bool indented}) {
  final lines = code.code.isEmpty ? <String>[] : code.code.split('\n');
  if (indented) {
    return [for (final line in lines) line.isEmpty ? '' : '    $line'];
  }
  final read = switch (code.source) {
    CodeBlock(:final fence?) => fence,
    _ => '```',
  };
  final char = read[0] == '`' && code.info.contains('`') ? '~' : read[0];
  final runs = lines.map(
    (line) =>
        RegExp('^ {0,3}(${RegExp.escape(char)}+)')
            .firstMatch(line)?[1]!
            .length ??
        0,
  );
  final length = [
    3,
    if (read[0] == char) read.length,
    runs.fold(0, (a, b) => a > b ? a : b) + 1,
  ].max;
  final fence = char * length;
  return ['$fence${infoEscaped(code.info)}', ...lines, fence];
}

/// Whether [code] prints indented: it was read so, has text on its first
/// and last line, is not [firstInItem], and would not join [previous].
bool printsIndented(
  CodeNode code,
  DocBlock? previous, {
  required bool firstInItem,
}) {
  final lines = code.code.split('\n');
  return code.source is CodeBlock &&
      !(code.source! as CodeBlock).fenced &&
      lines.first.trim().isNotEmpty &&
      lines.last.trim().isNotEmpty &&
      !joinsIndented(previous) &&
      !firstInItem;
}

/// Whether indented code after [previous] would join it: a list, or code
/// read as indented.
bool joinsIndented(DocBlock? previous) => switch (previous) {
  ListNode() => true,
  CodeNode(source: CodeBlock(fenced: false)) => true,
  _ => false,
};
