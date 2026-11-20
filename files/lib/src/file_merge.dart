import 'dart:typed_data';

/// Two versions of a file merged into one: the main file's [bytes] to
/// keep (`KeepMerged`), and what the merge couldn't keep of the other,
/// named so the user can find it (e.g. a calendar's event titles).
typedef MergedSides = ({Uint8List bytes, List<String> lost});

/// How two versions of one file type's files merge into one when the
/// user picks it, e.g. a conflict copy into its file.
abstract interface class FileMerge {
  /// [other] merged into [current], in [current]'s own style; `null` if
  /// the two can't be merged.
  MergedSides? merge(Uint8List current, Uint8List other);
}
