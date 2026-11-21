import 'dart:io';

import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

/// Edits to one file kept as a draft by an older app version, in its own
/// format: JSON with the text. Only read, so they are recovered once;
/// this reader goes once such drafts are all recovered.
@immutable
final class OldDraft {
  const OldDraft({
    required this.id,
    required this.path,
    required this.text,
    this.base,
    this.newSubfolder = false,
  });

  /// Names the draft in its store.
  final String id;

  /// The file in its folder; for a new file, where its file goes.
  final RelPath path;

  /// The file's text the edits started from; `null` for a new file.
  final String? base;

  /// The edited text.
  final String text;

  /// For a new file: [path]'s folder is a new subfolder the user asked
  /// for, made right before the file.
  final bool newSubfolder;

  /// `null` if [json] is not such a draft.
  static OldDraft? fromJson(String id, Object? json) => switch (json) {
    {'path': final String raw, 'text': final String text} => switch ((
      RelPath.parse(raw),
      json['base'],
    )) {
      (final path?, final String? base) => OldDraft(
        id: id,
        path: path,
        base: base,
        text: text,
        newSubfolder: json['newSubfolder'] == true,
      ),
      _ => null,
    },
    _ => null,
  };
}

/// The drafts an older app version left in one folder's drafts folder,
/// one JSON file each. Never written; the drafts of today's format beside
/// them are not theirs.
final class OldDrafts {
  OldDrafts(this._folder);

  final Directory _folder;

  static const _extension = '.json';

  /// Every draft last written before [before] (by default all), each
  /// `null` if it can't be read; `null` if they can't be listed.
  Future<List<OldDraft?>?> all({DateTime? before}) async {
    try {
      if (!await _folder.exists()) return const [];
      final drafts = <OldDraft?>[];
      await for (final file in _folder.list(followLinks: false)) {
        if (file is! File || !file.path.endsWith(_extension)) continue;
        if (before == null || (await file.lastModified()).isBefore(before)) {
          drafts.add(await _read(file));
        }
      }
      return drafts;
    } on FileSystemException {
      return null;
    }
  }

  /// How many files have readable drafts.
  Future<int> count() async => (await all())?.nonNulls.length ?? 0;

  /// Deletes the draft [id], once its edits are kept elsewhere.
  Future<void> remove(String id) async {
    try {
      await File('${_folder.path}/$id$_extension').delete();
    } on FileSystemException {
      // Tried again with the next recovery.
    }
  }

  Future<OldDraft?> _read(File file) async {
    final name = file.uri.pathSegments.last;
    final id = name.substring(0, name.length - _extension.length);
    return switch (await readJson(file)) {
      Ok(:final value) => OldDraft.fromJson(id, value),
      Err() => null,
    };
  }
}
