import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';

import 'document.dart';
import 'document_text.dart';

/// A version of a document as the app read or wrote it: owners only
/// compare it and hand it back typed; the app acts on its [read] text
/// (where the file is, how it is written). For a type that merges, a
/// version is the file's together with its conflict copies', so a new
/// copy is a new version. Equal to the [listedVersion] of the same files.
final class DocumentVersion extends Version {
  DocumentVersion(this.read)
    : super(
        _stampOf(read.document, [for (final read in read.copies) read.copy]),
      );

  final DocumentText read;
}

/// The version of [document] as listed, with the conflict [copies] its
/// type merges, to compare with the versions read.
Version listedVersion(
  Document document, {
  List<ConflictCopy> copies = const [],
}) => Version(_stampOf(document, copies));

/// A document's version, the same wherever it shows: the file version of
/// its key, and its copies' versions.
Object _stampOf(Document document, List<ConflictCopy> copies) => (
  document.key,
  document.version,
  _CopiesStamp([for (final copy in copies) (copy.id, copy.version)]),
);

/// The copies of a version, equal by their ids and versions.
final class _CopiesStamp {
  const _CopiesStamp(this._copies);

  final List<(String, FileVersion)> _copies;

  static const _equality = ListEquality<(String, FileVersion)>();

  @override
  bool operator ==(Object other) =>
      other is _CopiesStamp && _equality.equals(other._copies, _copies);

  @override
  int get hashCode => _equality.hash(_copies);
}

extension DocumentSeen on DocumentText {
  /// This document's file as the file owner sees it: its text and version.
  Seen<DocumentVersion> get seen => Seen(text, DocumentVersion(this));
}
