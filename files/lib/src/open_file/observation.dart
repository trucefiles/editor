import '../listed_file.dart';
import 'version.dart';

/// What the folder shows of one file now, as an open file hears it.
sealed class Observation {
  const Observation();
}

/// The file is there, in [version]. An open file reads a version it
/// hasn't seen itself.
final class Found extends Observation {
  const Found(this.version);

  final Version version;
}

/// The scan could not tell (e.g. the folder was out of reach).
final class Unknown extends Observation {
  const Unknown();
}

/// The file is gone.
final class Gone extends Observation {
  const Gone();
}

/// The version of [file] as listed, to compare with the versions read.
Version listedVersion(ListedFile file) => Version(versionStampOf(file));

/// A file's version stamp, the same wherever it shows: the file version
/// of its key.
Object versionStampOf(ListedFile file) => (file.key, file.version);
