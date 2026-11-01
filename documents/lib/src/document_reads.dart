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

  /// What the last [readAll] read, by key, with the version read; a file
  /// that couldn't be read is not here, so it is tried again.
  var _read = <DocumentKey, ({Version version, T? value})>{};

  /// What each of [listed] reads as, read anew where its version is new or
  /// its last read failed; a file that can't be read or reads as nothing
  /// is left out. Keeps only these, so documents gone are dropped.
  Future<Map<Document, T>> readAll(List<ListedDocument> listed) async {
    final read = {
      for (final (:document, :version) in listed)
        document.key: ?switch (_read[document.key]) {
          final known? when known.version == version => known,
          _ => await _readOf(document, version),
        },
    };
    _read = read;
    return {
      for (final (:document, version: _) in listed)
        document: ?read[document.key]?.value,
    };
  }

  /// [document] read in [version]; `null` if it couldn't be read.
  Future<({Version version, T? value})?> _readOf(
    Document document,
    Version version,
  ) async => switch (await _files.of(document.folder).reload(document)) {
    Ok(:final value) => (version: version, value: readAs(value)),
    Err() => null,
  };
}
