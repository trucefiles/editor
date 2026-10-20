import 'dart:convert';

import 'package:truce_core/src/markdown/inline/inline_reader.dart';
import 'package:truce_core/src/markdown/inline/inlines.dart';
import 'package:truce_core/src/markdown/tree/blocks.dart';
import 'package:truce_core/src/markdown/tree/characters.dart';

/// [root] as HTML, the way the spec's reference renderers (commonmark.js
/// and cmark-gfm) write it, so the tree and inlines can be checked
/// against the spec's examples; [filterTags] applies GitHub's tag filter
/// to raw HTML. Test-only.
String renderHtml(RootBlock root, {bool filterTags = false}) =>
    (_Renderer(_definitionsIn(root), filterTags: filterTags)..block(root)).html;

Map<String, LinkDefinition> _definitionsIn(MarkdownBlock block) =>
    switch (block) {
      ContainerBlock(:final children) =>
        children.map(_definitionsIn).fold({}, (all, more) => {...more, ...all}),
      DefinitionsBlock(:final definitions) => {
        for (final definition in definitions.reversed)
          normalizeLabel(definition.label): definition,
      },
      _ => const {},
    };

final class _Renderer {
  _Renderer(this._definitions, {required this.filterTags});

  final Map<String, LinkDefinition> _definitions;
  final bool filterTags;
  final _out = StringBuffer();
  var _last = '\n';
  var _inImage = 0;

  String get html => _out.toString();

  void block(MarkdownBlock block) {
    switch (block) {
      case RootBlock(:final children):
        children.forEach(this.block);
      case QuoteBlock(:final children):
        _cr();
        _tag('blockquote');
        _cr();
        children.forEach(this.block);
        _cr();
        _tag('/blockquote');
        _cr();
      case ListBlock():
        final first = block.items.first.marker;
        final name = first.isNumbered ? 'ol' : 'ul';
        final start = first.number;
        _cr();
        _tag(start != null && start != 1 ? '$name start="$start"' : name);
        _cr();
        block.children.forEach(this.block);
        _cr();
        _tag('/$name');
        _cr();
      case ItemBlock(:final checked, :final children):
        _tag('li');
        if (checked != null) {
          _lit(
            '<input ${checked ? 'checked="" ' : ''}disabled="" type="checkbox"> ',
          );
        }
        children.forEach(this.block);
        _tag('/li');
        _cr();
      case ParagraphBlock():
        final tight = switch (block.parent?.parent) {
          ListBlock(:final tight) => tight,
          _ => false,
        };
        if (!tight) {
          _cr();
          _tag('p');
        }
        _inlines(block.text);
        if (!tight) {
          _tag('/p');
          _cr();
        }
      case HeadingBlock(:final level, :final textStart, :final textEnd):
        _cr();
        _tag('h$level');
        _inlines(block.text, start: textStart, end: textEnd);
        _tag('/h$level');
        _cr();
      case CodeBlock(:final info):
        final language = info.split(RegExp(r'\s+')).first;
        _cr();
        _tag('pre');
        _tag(
          language.isEmpty
              ? 'code'
              : 'code class="language-${_escape(language)}"',
        );
        _lit(_escape(_codeOf(block)));
        _tag('/code');
        _tag('/pre');
        _cr();
      case HtmlBlock():
        _cr();
        _lit(_raw(block.text));
        _cr();
      case TableBlock():
        _table(block);
      case RuleBlock():
        _cr();
        _tag('hr /');
        _cr();
      case DefinitionsBlock() || FrontMatterBlock() || BlankBlock():
        break;
    }
  }

  void _table(TableBlock table) {
    final rows = [
      for (final (index, line) in table.lines.indexed)
        if (index != 1) line,
    ];
    void row(int index, String cell) {
      _tag('tr');
      _cr();
      for (final (column, alignment) in table.alignments.indexed) {
        final range = table.cells[index][column];
        final align = alignment == CellAlignment.none
            ? ''
            : ' align="${alignment.name}"';
        _tag('$cell$align');
        if (range != null) {
          final text = rows[index].content
              .substring(range.start, range.end)
              .replaceAll(r'\|', '|');
          _inlines(text);
        }
        _tag('/$cell');
        _cr();
      }
      _tag('/tr');
      _cr();
    }

    _cr();
    _tag('table');
    _cr();
    _tag('thead');
    _cr();
    row(0, 'th');
    _tag('/thead');
    _cr();
    if (rows.length > 1) {
      _tag('tbody');
      _cr();
      for (final index in Iterable.generate(
        rows.length - 1,
        (index) => index + 1,
      )) {
        row(index, 'td');
      }
      _tag('/tbody');
      _cr();
    }
    _tag('/table');
    _cr();
  }

  /// Renders the inlines of [text] from [start] to [end].
  void _inlines(String text, {int start = 0, int? end}) {
    _source = text;
    _spans(
      readInlines(text, start: start, end: end, definitions: _definitions),
    );
  }

  void _spans(List<Inline> inlines) => inlines.forEach(_inline);

  void _inline(Inline inline) {
    switch (inline) {
      case TextInline(:final literal):
        _lit(_escape(literal));
      case SoftBreakInline():
        _lit('\n');
      case HardBreakInline():
        _tag('br /');
        _cr();
      case CodeInline(:final literal):
        _tag('code');
        _lit(_escape(literal));
        _tag('/code');
      case HtmlInline(:final start, :final end):
        _lit(_raw(_source.substring(start, end)));
      case EmphasisInline(:final children):
        _wrap('em', children);
      case StrongInline(:final children):
        _wrap('strong', children);
      case StrikeInline(:final children):
        _wrap('del', children);
      case LinkInline(:final destination, :final title, :final children):
        final titled = title.isEmpty ? '' : ' title="${_escape(title)}"';
        _tag('a href="${_escape(_encodeUri(destination))}"$titled');
        _spans(children);
        _tag('/a');
      case ImageInline(:final destination, :final title, :final children):
        if (_inImage == 0)
          _lit('<img src="${_escape(_encodeUri(destination))}" alt="');
        _inImage++;
        _spans(children);
        _inImage--;
        if (_inImage == 0) {
          _lit(title.isEmpty ? '" />' : '" title="${_escape(title)}" />');
        }
    }
  }

  var _source = '';

  String _raw(String html) => filterTags ? _filtered(html) : html;

  void _wrap(String name, List<Inline> children) {
    _tag(name);
    _spans(children);
    _tag('/$name');
  }

  void _tag(String tag) {
    if (_inImage == 0) _lit('<$tag>');
  }

  void _cr() {
    if (_last != '\n') _lit('\n');
  }

  void _lit(String text) {
    if (text.isEmpty) return;
    _out.write(text);
    _last = text[text.length - 1];
  }
}

String _codeOf(CodeBlock code) => code.codeLines
    .map((line) => '${' ' * line.virtualSpaces}${line.content}\n')
    .join();

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// GitHub's tag filter: some raw tags are shown as text.
String _filtered(String html) => html.replaceAllMapped(
  RegExp(
    r'<(?=(title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext)[\s/>])',
    caseSensitive: false,
  ),
  (_) => '&lt;',
);

/// [uri] percent-encoded as commonmark.js does (mdurl): characters that
/// are not url-safe are encoded as UTF-8; valid escapes are kept.
String _encodeUri(String uri) {
  final out = StringBuffer();
  final runes = uri.runes.toList();
  for (var index = 0; index < runes.length; index++) {
    final char = String.fromCharCode(runes[index]);
    if (char == '%' && _isEscape(runes, index)) {
      out.write(char);
    } else if (_safe.hasMatch(char)) {
      out.write(char);
    } else {
      out.write(
        utf8
            .encode(char)
            .map(
              (byte) =>
                  '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
            )
            .join(),
      );
    }
  }
  return out.toString();
}

bool _isEscape(List<int> runes, int index) =>
    index + 2 < runes.length &&
    RegExp(r'^[0-9a-fA-F]{2}$')
        .hasMatch(String.fromCharCodes(runes.sublist(index + 1, index + 3)));

final _safe = RegExp(r"^[A-Za-z0-9;/?:@&=+$,\-_.!~*'()#]$");
