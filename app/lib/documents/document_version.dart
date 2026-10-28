import 'package:truce_core/truce_core.dart';

import 'document.dart';
import 'document_text.dart';

/// A version of a document's file as the app read or wrote it: owners only
/// compare it; the app acts on its [read] text (where the file is, how it
/// is written). Equal to the [listedVersion] of the same file version.
final class DocumentVersion extends Version {
  DocumentVersion(this.read) : super(_stampOf(read.document));

  final DocumentText read;
}

/// The version of [document] as listed, to compare with the versions read.
Version listedVersion(Document document) => Version(_stampOf(document));

/// A document's version, the same wherever it shows: the file version of
/// its key.
Object _stampOf(Document document) => (document.key, document.version);

extension DocumentSeen on DocumentText {
  /// This document's file as the file owner sees it: its text and version.
  Seen get seen => Seen(text, DocumentVersion(this));
}

/// The document [version] was read or written as. Every version the app
/// hands to a file owner as seen is a [DocumentVersion].
DocumentText documentOf(Version version) => (version as DocumentVersion).read;
