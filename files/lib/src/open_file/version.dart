/// One version of a file: a stamp of its content, compared
/// for equality only. Whoever reads the files may extend it to carry what
/// it needs to act on that version (where the file is, how it is
/// written); owners only compare versions and hand them back typed.
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
