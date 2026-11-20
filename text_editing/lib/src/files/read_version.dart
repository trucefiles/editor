import 'package:truce_files/truce_files.dart';

import '../text/seen.dart';
import 'file_text.dart';

/// A version of a file as the app read or wrote it: owners only
/// compare it and hand it back typed; the app acts on its [read] text
/// (where the file is, how it is written). Equal to the [listedVersion] of
/// the same file version.
final class ReadVersion extends Version {
  ReadVersion(this.read) : super(versionStampOf(read.listed));

  final FileText read;
}

extension FileSeen on FileText {
  /// This file as the file owner sees it: its text and version.
  Seen<ReadVersion> get seen => Seen(text, ReadVersion(this));
}
