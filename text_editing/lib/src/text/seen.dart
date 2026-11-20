import 'package:truce_files/truce_files.dart';

/// A version of a file with the text it holds; [V] is the
/// kind of version its reader made, handed back as it is.
final class Seen<V extends Version> {
  const Seen(this.text, this.version);

  final String text;
  final V version;

  @override
  bool operator ==(Object other) =>
      other is Seen && other.version == version && other.text == text;

  @override
  int get hashCode => Object.hash(version, text);

  @override
  String toString() => 'Seen($version)';
}
