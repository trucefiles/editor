import 'package:truce_core/truce_core.dart';

import 'document_type.dart';
import 'new_document.dart';

/// The document types the app handles, and which one a file is.
final class DocumentTypes<T extends DocumentType> {
  /// [newDocuments]: what the user can make new, a plain new document
  /// first; never empty.
  DocumentTypes(List<T> types, {required this.newDocuments})
    : assert(newDocuments.isNotEmpty, 'Nothing to make new.'),
      detector = ExtensionFileTypeDetector.of([
        for (final type in types) type.support,
      ]),
      _byId = {for (final type in types) type.support.type: type};

  /// Tells which handled type a file is; the files of no handled type
  /// are not shown.
  final FileTypeDetector detector;

  /// What the user can make new, a plain new document first.
  final List<NewDocument<T>> newDocuments;

  /// The type of a plain new document.
  T get forNew => newDocuments.first.type;

  final Map<FileType, T> _byId;

  /// The type of the file at [path]; `null` if the app doesn't handle it,
  /// e.g. a path kept from an older app version.
  T? of(RelPath path) => switch (detector.detect(path)) {
    final type? => _byId[type],
    null => null,
  };

  /// The app's type of a document whose file is of [type].
  T ofFile(FileTypeSupport<Object?> type) => _byId[type.type]!;

  /// How texts of the file at [path] merge; `null` if they don't, or the
  /// app doesn't handle it.
  TextMerge? mergeOf(RelPath path) => of(path)?.merge;

  /// Whether the app handles the file at [path].
  bool handles(RelPath path) => of(path) != null;
}
