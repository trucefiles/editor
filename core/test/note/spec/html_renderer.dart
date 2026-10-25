import 'dart:convert';

import 'package:truce_core/src/note/tree/blocks.dart';
import 'package:truce_core/src/note/tree/inlines.dart';

/// [root] as HTML, the way the spec's reference renderers (commonmark.js
/// and cmark-gfm) write it, so the tree can be checked against the
/// spec's examples; [filterTags] applies GitHub's tag filter to raw
/// HTML. Test-only.
String renderHtml(RootBlock root, {bool filterTags = false}) =>
    (_Renderer(filterTags: filterTags)..block(root, tight: false)).html;

final class _Renderer {
  _Renderer({required this.filterTags});

  final bool filterTags;
  final _out = StringBuffer();
  var _last = '\n';
  var _inImage = 0;

  String get html => _out.toString();

  void block(Block block, {required bool tight}) {
    switch (block) {
      case RootBlock(:final children):
        for (final child in children) {
          this.block(child, tight: false);
        }
      case QuoteBlock(:final children):
        _cr();
        _tag('blockquote');
        _cr();
        for (final child in children) {
          this.block(child, tight: false);
        }
        _cr();
        _tag('/blockquote');
        _cr();
      case ListBlock():
        final first = block.items.first.marker;
        final name = first.kind == ListKind.numbered ? 'ol' : 'ul';
        final start = first.number;
        _cr();
        _tag(start != null && start != 1 ? '$name start="$start"' : name);
        _cr();
        for (final item in block.items) {
          this.block(item, tight: !block.loose);
        }
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
        for (final child in children) {
          this.block(child, tight: tight);
        }
        _tag('/li');
        _cr();
      case ParagraphBlock(:final text):
        if (!tight) {
          _cr();
          _tag('p');
        }
        _spans(text.inlines);
        if (!tight) {
          _tag('/p');
          _cr();
        }
      case HeadingBlock(:final level, :final text):
        _cr();
        _tag('h$level');
        _spans(text.inlines);
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
        _lit(_escape(block.codeLines.isEmpty ? '' : '${block.code}\n'));
        _tag('/code');
        _tag('/pre');
        _cr();
      case HtmlBlock(:final content):
        _cr();
        _lit(_raw(content));
        _cr();
      case TableBlock():
        _table(block);
      case RuleBlock():
        _cr();
        _tag('hr /');
        _cr();
      case DefinitionsBlock() || FrontMatterBlock():
        break;
    }
  }

  void _table(TableBlock table) {
    void row(List<InlineText> cells, String cell) {
      _tag('tr');
      _cr();
      for (final (column, alignment) in table.alignments.indexed) {
        final align = alignment == CellAlignment.none
            ? ''
            : ' align="${alignment.name}"';
        _tag('$cell$align');
        _spans(cells[column].inlines);
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
    row(table.rows.first, 'th');
    _tag('/thead');
    _cr();
    if (table.rows.length > 1) {
      _tag('tbody');
      _cr();
      for (final cells in table.rows.skip(1)) {
        row(cells, 'td');
      }
      _tag('/tbody');
      _cr();
    }
    _tag('/table');
    _cr();
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
      case HtmlInline(:final source):
        _lit(_raw(source));
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
        if (_inImage == 0) {
          _lit('<img src="${_escape(_encodeUri(destination))}" alt="');
        }
        _inImage++;
        _spans(children);
        _inImage--;
        if (_inImage == 0) {
          _lit(title.isEmpty ? '" />' : '" title="${_escape(title)}" />');
        }
    }
  }

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
