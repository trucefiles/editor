import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

/// What waits on this device to go into one file of a folder: the
/// [head] and the bytes to write ([content]).
@immutable
final class Draft {
  const Draft(this.head, this.content);

  final DraftHead head;
  final Uint8List content;
}

/// A draft without its content: enough to list drafts without loading
/// them.
@immutable
final class DraftHead {
  const DraftHead({required this.id, required this.path, required this.of});

  /// Random, so any file path fits; names the draft in its store.
  final String id;

  /// The file in its folder; for a new file, where it goes, with a number
  /// added if the name is taken.
  final RelPath path;

  final DraftOf of;

  static final _random = Random.secure();

  static String newId() =>
      List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();
}

/// Whose file a draft waits for.
sealed class DraftOf {
  const DraftOf();
}

/// A new file, not written yet: its content is the file as it will be
/// written. [newSubfolder]: its path's folder is a new one the user asked
/// for, made right before the file.
final class NewFileDraft extends DraftOf {
  const NewFileDraft({this.newSubfolder = false});

  final bool newSubfolder;
}

/// A draft its user puts into its file itself, at the next start, by the
/// step it plugs in (e.g. the text kit's edits to a saved file). [part] is
/// that user's own and opaque here.
final class OwnDraft extends DraftOf {
  const OwnDraft(this.part);

  final String part;
}
