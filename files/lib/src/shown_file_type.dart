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

  /// What cards show of a file read, `null` if the type can't show what
  /// that one holds (e.g. a text type's file that isn't text). `null`
  /// here: a card shows its name only, and its file is never read for it
  /// (e.g. pictures, whose cards their page type draws).
  FileCardSummary? Function(FileBytes read)? get cardSummary;

  /// How search reads a file of this type: the title and words it finds
  /// in a read (e.g. its whole text, or only what shows of it), `null`
  /// if the type can't read that one. `null` here: search finds its files
  /// by name only and never reads them (e.g. pictures).
  SearchText? Function(FileBytes read)? get searchText;

  /// Whether the user edits its files in the app, so they show among the
  /// recently edited; `false` for a type only looked at (e.g. pictures).
  bool get edited;

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
