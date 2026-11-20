import 'shown_file_type.dart';

/// What a new file starts from. Only the type's own page reads it (e.g.
/// a text type's start text), so this layer knows no cases.
abstract interface class NewFileStart {}

/// Something new of a type the user can make, called [label] where the
/// user picks it (e.g. "Health calendar"), starting from [start]; `null`
/// starts it empty.
final class NewFileKind {
  const NewFileKind(this.label, {this.start});

  final String label;
  final NewFileStart? start;
}

/// Something new the user can make: a file of [type], as [kind] says.
final class NewFileChoice<T extends ShownFileType> {
  const NewFileChoice(this.kind, this.type);

  final NewFileKind kind;
  final T type;

  String get label => kind.label;
}
