import 'package:truce_core/truce_core.dart';

import 'file_card_summary.dart';
import 'file_text.dart';
import 'new_file_choice.dart';

/// What one file type brings: its files ([support]), what cards show
/// of a text, and whether two texts of it can be merged ([merge]).
abstract interface class ShownFileType {
  FileTypeSupport<Object?> get support;

  /// The type's name as the user sees it, e.g. "Calendar".
  String get name;

  /// The byte style of a new file of this type (e.g. its line breaks).
  TextFile get newFile;

  /// What new files of this type the user can make, in the order the
  /// user picks from; empty if none.
  List<NewFileKind> get newKinds;

  /// What cards and search show of [read], from its summary.
  FileCardSummary cardSummary(FileText read);

  /// The words a search finds in [read] (e.g. its whole text, or only
  /// what shows of it).
  String searchText(FileText read);

  /// How two texts of this type merge into one when the user picks it,
  /// e.g. a conflict copy into its file; `null` if they don't (the user
  /// keeps one side).
  TextMerge? get merge;
}

/// What every file type gives the same way.
extension NewFileExtension on ShownFileType {
  /// The extension of a new file of this type, with its dot: its
  /// support's first.
  String get newFileExtension => '.${support.extensions.first}';
}
