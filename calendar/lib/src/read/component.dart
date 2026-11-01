import 'content_line.dart';

/// One component of an iCalendar text (`BEGIN:NAME` … `END:NAME`): its
/// property lines and the components inside it, in order. An immutable
/// value; edits make a new one.
final class Component {
  const Component(this.name, this.properties, {this.children = const []});

  /// The component's name, upper case (`VEVENT`).
  final String name;
  final List<ContentLine> properties;
  final List<Component> children;

  /// The first property [name]; `null` if there is none.
  ContentLine? property(String name) =>
      properties.where((line) => line.name == name).firstOrNull;

  /// Every property [name], in order.
  Iterable<ContentLine> all(String name) =>
      properties.where((line) => line.name == name);

  /// The value of the first property [name]; `null` if there is none.
  String? value(String name) => property(name)?.value;

  /// This component with property [name] set to [line] (`null`: none),
  /// where its first one was, or at the end; every other one of [name]
  /// goes. Unchanged if it already holds just that line.
  Component withProperty(String name, ContentLine? line) {
    final lines = all(name).toList();
    if (line == null
        ? lines.isEmpty
        : lines.length == 1 && _same(lines.single, line)) {
      return this;
    }
    final at = properties.indexWhere((property) => property.name == name);
    final others = [
      for (final property in properties)
        if (property.name != name) property,
    ];
    final place = at < 0 ? others.length : at;
    return Component(this.name, [
      ...others.take(place),
      ?line,
      ...others.skip(place),
    ], children: children);
  }

  /// This component holding [children] instead.
  Component withChildren(List<Component> children) =>
      Component(name, properties, children: children);

  /// The component printed fresh, its property lines as they were read
  /// where an edit left them.
  String get printed => [
    'BEGIN:$name\n',
    for (final line in properties) '${line.printed}\n',
    for (final child in children) child.printed,
    'END:$name\n',
  ].join();

  /// Whether [a] and [b] say the same.
  static bool _same(ContentLine a, ContentLine b) => a.unfolded == b.unfolded;
}

/// The component read from [lines], which start with its `BEGIN` and end
/// with its `END`; `null` if they don't nest.
Component? readComponent(List<({String unfolded, String raw})> lines) {
  final stack =
      <
        ({String name, List<ContentLine> properties, List<Component> children})
      >[];
  Component? done;
  for (final (:unfolded, :raw) in lines) {
    final line = ContentLine.parse(unfolded, raw: raw);
    if (line == null || done != null) return null;
    switch (line.name) {
      case 'BEGIN':
        stack.add((
          name: line.value.toUpperCase(),
          properties: [],
          children: [],
        ));
      case 'END'
          when stack.isNotEmpty && stack.last.name == line.value.toUpperCase():
        final open = stack.removeLast();
        final component = Component(
          open.name,
          open.properties,
          children: open.children,
        );
        if (stack.isEmpty) {
          done = component;
        } else {
          stack.last.children.add(component);
        }
      case _ when stack.isEmpty:
        return null;
      case _:
        stack.last.properties.add(line);
    }
  }
  return done;
}
