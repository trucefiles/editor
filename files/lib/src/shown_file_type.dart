import 'package:truce_core/truce_core.dart';

import 'file_bytes.dart';
import 'file_card_summary.dart';
import 'file_merge.dart';
import 'new_file_choice.dart';

/// What one file type brings: its files ([support]), what cards and
/// search take from a file read, and whether two versions of it can be
/// merged ([merge]). Neutral to how a type reads its bytes.
abstract interface class ShownFileType {
  FileTypeSupport get support;

  /// The type's name as the user sees it, e.g. "Calendar".
  String get name;

  /// What new files of this type the user can make, in the order the
  /// user picks from; empty if none.
  List<NewFileKind> get newKinds;

  /// What cards show of [read]; `null` if the type can't show what it
  /// holds (e.g. a text type's file that isn't text).
  FileCardSummary? cardSummary(FileBytes read);

  /// The title and words a search finds in [read] (e.g. its whole text,
  /// or only what shows of it); `null` if the type can't read it.
  SearchText? searchText(FileBytes read);

  /// How two versions of this type merge into one when the user picks
  /// it, e.g. a conflict copy into its file; `null` if they don't (the
  /// user keeps one side).
  FileMerge? get merge;
}

/// What every file type gives the same way.
extension NewFileExtension on ShownFileType {
  /// The extension of a new file of this type, with its dot: its
  /// support's first.
  String get newFileExtension => '.${support.extensions.first}';
}
