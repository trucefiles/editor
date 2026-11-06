import 'shown_file_type.dart';

/// Something new of a type the user can make, called [label] where the
/// user picks it (e.g. "Health calendar"), starting with [start]: the
/// text it opens with, written only once the user changes it.
final class NewFileKind {
  const NewFileKind(this.label, {this.start = ''});

  final String label;
  final String start;
}

/// Something new the user can make: a file of [type], as [kind] says.
final class NewFileChoice<T extends ShownFileType> {
  const NewFileChoice(this.kind, this.type);

  final NewFileKind kind;
  final T type;

  String get label => kind.label;
}
