import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'file_place.dart';
import 'shown_file_type.dart';

/// How a file's links change: the new destination for a link to
/// [destination], `null` to keep it.
typedef Relink = String? Function(String destination);

/// The files the app keeps for the texts of a folder's files, apart from
/// them (e.g. the images documents show): what moving and restoring a
/// file needs of them. Implemented above `files` and handed in at the
/// wiring; [NoLinkedFiles] where the app keeps none.
abstract interface class LinkedFiles {
  /// Copies the kept files [text] links from [from] into [to], with
  /// their names, before a file holding [text] moves there; one already
  /// there is done. Fails if one can't be copied: the file then stays.
  Future<Result<void, StoreError>> copyFor(
    String text, {
    required Folder from,
    required Folder to,
  });

  /// How the links of the file at [from] in [folder] change when it moves
  /// into [toFolder] (`null`: the top level) of that folder or another
  /// one holding the same kept files; `null` if none change.
  Future<Result<Relink?, StoreError>> relinkFor(
    Folder folder, {
    required RelPath from,
    required RelPath? toFolder,
  });

  /// Brings back the kept files [text] links that [folder] lacks, from
  /// their backups, before a text is restored there. Best effort: the
  /// restore never waits on a failure.
  Future<void> bringBack(String text, Folder folder);
}

/// No files are kept for any text.
final class NoLinkedFiles implements LinkedFiles {
  const NoLinkedFiles();

  @override
  Future<Result<void, StoreError>> copyFor(
    String text, {
    required Folder from,
    required Folder to,
  }) async => const Ok(null);

  @override
  Future<Result<Relink?, StoreError>> relinkFor(
    Folder folder, {
    required RelPath from,
    required RelPath? toFolder,
  }) async => const Ok(null);

  @override
  Future<void> bringBack(String text, Folder folder) async {}
}

/// The one rule for a file's text as it changes place.
extension TextAtPlace on LinkedFiles {
  /// What a file of [type] holding [text], at [from] in [folder], holds
  /// once at [to]: the kept files it links go along into [to]'s folder
  /// first, then its links change where they must; `null` if its text
  /// stays. Fails if the kept files can't go along or be looked up.
  Future<Result<String?, StoreError>> textAt(
    FilePlace to,
    String text, {
    required ShownFileType? type,
    required Folder folder,
    required RelPath from,
  }) async {
    if (to.folder.id != folder.id) {
      final copied = await copyFor(text, from: folder, to: to.folder);
      if (copied case Err(:final error)) return Err(error);
    }
    final relink = await relinkFor(folder, from: from, toFolder: to.subfolder);
    return relink.map(
      (relink) => switch ((relink, type)) {
        (final relink?, final type?) => type.relinked(text, relink),
        _ => null,
      },
    );
  }
}
