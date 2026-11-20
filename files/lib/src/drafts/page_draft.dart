import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'draft.dart';
import 'file_drafts.dart';

/// The one draft of an open page: [id] names it in whichever folder's
/// drafts it is kept. Kept in one folder at a time: once a keep lands, it
/// is dropped from every other folder it was kept in (a new file whose
/// place changed), so no copy of it waits anywhere else.
final class PageDraft {
  PageDraft(this._draftsOf);

  final FileDrafts Function(Folder folder) _draftsOf;

  /// Names the draft in each folder's drafts.
  final id = DraftHead.newId();

  /// The folders that may hold the draft, by id.
  final _keptIn = <FolderId, Folder>{};

  /// Keeps and drops run one at a time, in the order asked.
  final _turns = KeyedTaskQueue<String>();

  /// Keeps [draft] (named by [id]) in [folder]'s drafts, then drops it
  /// from every other folder. Whether it is kept.
  Future<bool> keep(Folder folder, Draft draft) => _turns.run(id, () async {
    _keptIn[folder.id] = folder;
    if (!await _draftsOf(folder).keep(draft)) return false;
    await _dropAll(except: folder.id);
    return true;
  });

  /// Drops the draft from every folder, once its content is kept
  /// elsewhere or the user dropped it.
  Future<void> drop() => _turns.run(id, _dropAll);

  Future<void> _dropAll({FolderId? except}) async {
    final others = [..._keptIn.keys.where((folder) => folder != except)];
    for (final folder in others) {
      await _draftsOf(_keptIn.remove(folder)!).remove(id);
    }
  }
}
