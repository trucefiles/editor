import 'package:truce_core/truce_core.dart';

import 'document_type.dart';

/// The document types the app handles, and which one a file is.
final class DocumentTypes<T extends DocumentType> {
  DocumentTypes(List<T> types, {required this.forNew})
    : detector = ExtensionFileTypeDetector.of([
        for (final type in types) type.support,
      ]),
      _byId = {for (final type in types) type.support.type: type};

  /// Tells which handled type a file is; the files of no handled type
  /// are not shown.
  final FileTypeDetector detector;

  /// The type new documents are created in.
  final T forNew;

  final Map<FileType, T> _byId;

  /// The type of the file at [path]; `null` if the app doesn't handle it,
  /// e.g. a path kept from an older app version.
  T? of(RelPath path) => switch (detector.detect(path)) {
    final type? => _byId[type],
    null => null,
  };

  /// The app's type of a document whose file is of [type].
  T ofFile(FileTypeSupport<Object?> type) => _byId[type.type]!;

  /// Whether the app handles the file at [path].
  bool handles(RelPath path) => of(path) != null;
}
