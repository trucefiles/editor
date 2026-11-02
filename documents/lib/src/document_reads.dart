import 'package:truce_core/truce_core.dart';

import 'document.dart';
import 'document_files.dart';
import 'document_text.dart';

/// What a set of documents read as (e.g. each calendar of the Calendar
/// tab): [readAs] turns a document's text into what is kept of it, `null`
/// if nothing is. A document is read again only once it changes (a new
/// version as listed).
final class DocumentReads<T extends Object> {
  DocumentReads(this._files, {required this.readAs});

  final FolderFiles _files;
  final T? Function(DocumentText read) readAs;

  /// What the last [readAll] read, by key, as the document was listed; a
  /// file that couldn't be read is not here, so it is tried again.
  var _read = <DocumentKey, ({Document document, T? value})>{};

  /// What each of [listed] reads as, read anew where it changed or its
  /// last read failed; a file that can't be read or reads as nothing is
  /// left out. Keeps only these, so documents gone are dropped.
  Future<Map<Document, T>> readAll(List<Document> listed) async {
    final read = {
      for (final document in listed)
        document.key: ?switch (_read[document.key]) {
          final known? when known.document == document => known,
          _ => await _readOf(document),
        },
    };
    _read = read;
    return {
      for (final document in listed) document: ?read[document.key]?.value,
    };
  }

  /// [document] read now; `null` if it couldn't be read.
  Future<({Document document, T? value})?> _readOf(Document document) async =>
      switch (await _files.of(document.folder).reload(document)) {
        Ok(:final value) => (document: document, value: readAs(value)),
        Err() => null,
      };
}
