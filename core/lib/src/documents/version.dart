/// One version of a document's file: a stamp of its content, compared
/// for equality only. Whoever reads the files may extend it to carry what
/// it needs to act on that version (where the file is, how it is
/// written); owners only compare versions and hand them back typed (see
/// [Seen]).
base class Version {
  const Version(this._stamp);

  final Object _stamp;

  @override
  bool operator ==(Object other) => other is Version && other._stamp == _stamp;

  @override
  int get hashCode => _stamp.hashCode;

  @override
  String toString() => 'Version($_stamp)';
}

/// A version of a document's file with the text it holds; [V] is the
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
