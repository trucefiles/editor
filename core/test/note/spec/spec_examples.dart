import 'dart:io';

/// One example of a Markdown spec: its [markdown] and the [html] it
/// renders to.
typedef SpecExample = ({
  int number,
  String section,
  String markdown,
  String html,
});

/// The examples of the spec file [name] in this folder, numbered from 1
/// as the spec numbers them.
List<SpecExample> specExamples(String name) {
  final lines = File('test/note/spec/$name').readAsLinesSync();
  final examples = <SpecExample>[];
  var section = '';
  var part = _Part.outside;
  final markdown = StringBuffer();
  final html = StringBuffer();
  for (final line in lines) {
    switch (part) {
      case _Part.outside
          when line.startsWith(_fence) && line.contains('example'):
        part = _Part.markdown;
      case _Part.outside when line.startsWith('#'):
        section = line.replaceFirst(RegExp('^#+ '), '');
      case _Part.outside:
        break;
      case _Part.markdown when line == '.':
        part = _Part.html;
      case _Part.markdown:
        markdown.writeln(line);
      case _Part.html when line.startsWith(_fence):
        examples.add((
          number: examples.length + 1,
          section: section,
          markdown: _withTabs(markdown.toString()),
          html: _withTabs(html.toString()),
        ));
        markdown.clear();
        html.clear();
        part = _Part.outside;
      case _Part.html:
        html.writeln(line);
    }
  }
  return examples;
}

enum _Part { outside, markdown, html }

final _fence = '`' * 32;

String _withTabs(String text) => text.replaceAll('→', '\t');
