import 'document_type.dart';

/// Something new the user can make: a document of [type], called [label]
/// where the user picks it (e.g. "Calendar").
final class NewDocument<T extends DocumentType> {
  const NewDocument(this.label, this.type, {this.startNamed});

  final String label;
  final T type;

  /// The text it starts with for the name the user gives it first (e.g. a
  /// calendar's own name); `null`: it starts empty, with no name asked.
  final String Function(String name)? startNamed;

  /// Whether the user names it before it opens.
  bool get named => startNamed != null;

  /// The text it starts with, named [name].
  String startText(String name) => startNamed?.call(name) ?? '';
}
