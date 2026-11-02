import 'package:truce_core/truce_core.dart';

import 'file_text.dart';
import 'listed_file.dart';

/// A version of a file as the app read or wrote it: owners only
/// compare it and hand it back typed; the app acts on its [read] text
/// (where the file is, how it is written). Equal to the [listedVersion] of
/// the same file version.
final class ReadVersion extends Version {
  ReadVersion(this.read) : super(_stampOf(read.listed));

  final FileText read;
}

/// The version of [file] as listed, to compare with the versions read.
Version listedVersion(ListedFile file) => Version(_stampOf(file));

/// A file's version, the same wherever it shows: the file version of
/// its key.
Object _stampOf(ListedFile file) => (file.key, file.version);

extension FileSeen on FileText {
  /// This file as the file owner sees it: its text and version.
  Seen<ReadVersion> get seen => Seen(text, ReadVersion(this));
}
