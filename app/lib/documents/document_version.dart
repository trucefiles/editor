import 'package:truce_core/truce_core.dart';

import 'document.dart';

/// A version of a document's file as the app read or wrote it: owners only
/// compare it; the app acts on its [document] (where the file is, how it is
/// written).
final class DocumentVersion extends Version {
  DocumentVersion(this.document)
    : super((document.folder.id, document.path, document.version));

  final Document document;
}

extension DocumentSeen on Document {
  /// This document's file as the file owner sees it: its text and version.
  Seen get seen => Seen(file.text, DocumentVersion(this));
}

/// The document [version] was read or written as. Every version the app
/// hands to a file owner is a [DocumentVersion].
Document documentOf(Version version) => (version as DocumentVersion).document;
