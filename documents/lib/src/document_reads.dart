import 'package:truce_core/truce_core.dart';

import 'document.dart';
import 'document_files.dart';
import 'document_text.dart';

/// A document as listed: the [document] and its [version] with the copies
/// read into it.
typedef ListedDocument = ({Document document, Version version});

/// What a set of documents read as (e.g. each calendar of the Calendar
/// tab), merged with their copies as every read is: [readAs] turns a
/// document's text into what is kept of it, `null` if nothing is. A
/// document is read again only once its version changes.
final class DocumentReads<T extends Object> {
  DocumentReads(this._files, {required this.readAs});

  final FolderFiles _files;
  final T? Function(DocumentText read) readAs;

  /// What the last [readAll] kept, by key, with the version read.
  var _read = <DocumentKey, ({Version version, T? value})>{};

  /// What each of [listed] reads as, read anew where its version is new; a
  /// file that can't be read or reads as nothing is left out. Keeps only
  /// these, so documents gone are dropped.
  Future<Map<Document, T>> readAll(List<ListedDocument> listed) async {
    final read = {
      for (final (:document, :version) in listed)
        document.key: switch (_read[document.key]) {
          final known? when known.version == version => known,
          _ => (version: version, value: await _valueOf(document)),
        },
    };
    _read = read;
    return {
      for (final (:document, version: _) in listed)
        document: ?read[document.key]?.value,
    };
  }

  Future<T?> _valueOf(Document document) async =>
      switch (await _files.of(document.folder).reload(document)) {
        Ok(:final value) => readAs(value),
        Err() => null,
      };
}
