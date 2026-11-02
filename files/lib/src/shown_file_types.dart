import 'package:truce_core/truce_core.dart';

import 'new_file_choice.dart';
import 'shown_file_type.dart';

/// The file types the app handles, and which one a file is.
final class ShownFileTypes<T extends ShownFileType> {
  /// [newDocuments]: what the user can make new, a plain new file
  /// first; never empty.
  ShownFileTypes(List<T> types, {required this.newFileChoices})
    : assert(newFileChoices.isNotEmpty, 'Nothing to make new.'),
      detector = ExtensionFileTypeDetector.of([
        for (final type in types) type.support,
      ]),
      _byId = {for (final type in types) type.support.type: type};

  /// Tells which handled type a file is; the files of no handled type
  /// are not shown.
  final FileTypeDetector detector;

  /// What the user can make new, a plain new file first.
  final List<NewFileChoice<T>> newFileChoices;

  /// The type of a plain new file.
  T get forNew => newFileChoices.first.type;

  final Map<FileType, T> _byId;

  /// The type of the file at [path]; `null` if the app doesn't handle it,
  /// e.g. a path kept from an older app version.
  T? of(RelPath path) => switch (detector.detect(path)) {
    final type? => _byId[type],
    null => null,
  };

  /// The app's type of a file whose file is of [type].
  T ofFile(FileTypeSupport<Object?> type) => _byId[type.type]!;

  /// How texts of the file at [path] merge; `null` if they don't, or the
  /// app doesn't handle it.
  TextMerge? mergeOf(RelPath path) => of(path)?.merge;

  /// Whether the app handles the file at [path].
  bool handles(RelPath path) => of(path) != null;
}
