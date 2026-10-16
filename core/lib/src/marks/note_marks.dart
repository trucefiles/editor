import 'package:pool/pool.dart';

import '../common/result.dart';
import '../filter/file_filter.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'note_mark.dart';
import 'note_marks_file.dart';

/// Pins and colors of the notes in one folder, kept in the folder itself so
/// they sync with it.
///
/// Each device writes only its own file, `.truce/marks/<device id>.json`
/// (see [NoteMarksFile]), so marks never cause a sync conflict. Reading
/// merges the files of all devices: per note, the newest mark wins.
///
/// Marks are keyed by path: a note renamed or moved outside the app loses
/// its mark. Each write of this device's file also drops the marks of
/// notes that are gone, so the file never keeps growing. Only writes do:
/// they come from user actions, while a write on its own would sync to
/// every device.
final class NoteMarks {
  /// [deviceId] must be unique per device and a valid file name.
  NoteMarks(this._store, {required String deviceId, DateTime Function()? now})
    : _ownFile = RelPath.parse('$_folder/$deviceId.json')!,
      _now = now ?? DateTime.now;

  static const _folder = '.truce/marks';

  /// The files that hold the marks of all devices, e.g. to follow other
  /// devices' changes to them.
  static const FileFilter files = _MarksFiles();

  final FileStore _store;
  final RelPath _ownFile;
  final DateTime Function() _now;

  /// Changes to this device's file, one at a time.
  final _changes = Pool(1);

  /// The marked notes; unmarked ones are left out. Skips device files that
  /// cannot be read.
  Future<Result<Map<RelPath, NoteMark>, StoreError>> load() async {
    final List<FileEntry> entries;
    switch (await _store.list(
      enterFolder: _leadsToFolder,
      includeFile: _isDeviceFile,
    )) {
      case Ok(:final value):
        entries = value.files;
      case Err(:final error):
        return Err(error);
    }
    final newest = <RelPath, StampedMark>{};
    for (final entry in entries) {
      if (await _store.read(entry.path) case Ok(:final value)) {
        NoteMarksFile.decode(value.bytes)?.forEach((note, stamped) {
          final known = newest[note];
          if (known == null || stamped.changed.isAfter(known.changed)) {
            newest[note] = stamped;
          }
        });
      }
    }
    return Ok({
      for (final MapEntry(:key, :value) in newest.entries)
        if (!value.mark.isNone) key: value.mark,
    });
  }

  /// Sets the mark of [note] in this device's file. Fails with
  /// [StoreError.ioFailure] if the file cannot be read as marks, instead of
  /// writing over the marks in it. Runs after every earlier change, so each
  /// starts from the marks the one before wrote.
  Future<Result<void, StoreError>> set(RelPath note, NoteMark mark) =>
      _changes.withResource(
        () => _change((marks) {
          marks[note] = (mark: mark, changed: _now());
          return true;
        }),
      );

  /// Drops the mark of [note] from this device's file, e.g. as the user
  /// deletes it. As [set]; writes nothing if there is nothing to drop.
  Future<Result<void, StoreError>> remove(RelPath note) => _changes
      .withResource(() => _change((marks) => marks.remove(note) != null));

  /// Applies [apply] to this device's marks and writes them, without the
  /// marks of gone notes, if [apply] or that changed any.
  Future<Result<void, StoreError>> _change(
    bool Function(Map<RelPath, StampedMark> marks) apply,
  ) async {
    final FileVersion? version;
    final Map<RelPath, StampedMark> marks;
    switch (await _store.read(_ownFile)) {
      case Ok(:final value):
        version = value.version;
        final decoded = NoteMarksFile.decode(value.bytes);
        if (decoded == null) return const Err(StoreError.ioFailure);
        marks = decoded;
      case Err(error: StoreError.notFound):
        version = null;
        marks = {};
      case Err(:final error):
        return Err(error);
    }
    final applied = apply(marks);
    final pruned = await _dropGone(marks);
    if (!applied && !pruned) return const Ok(null);
    final bytes = NoteMarksFile.encode(marks);
    final written = version == null
        ? await _store.create(_ownFile, bytes)
        : await _store.replace(_ownFile, bytes, ifUnchanged: version);
    return switch (written) {
      Ok() => const Ok(null),
      Err(:final error) => Err(error),
    };
  }

  /// Drops the marks of notes that are no longer in the folder; keeps
  /// those that cannot be told, e.g. in a subfolder that can't be read.
  /// Returns whether it dropped any.
  Future<bool> _dropGone(Map<RelPath, StampedMark> marks) async {
    final notes = marks.keys.map((note) => note.value).toSet();
    final listed = await _store.list(
      enterFolder: (folder) =>
          notes.any((note) => note.startsWith('${folder.value}/')),
      includeFile: (file) => notes.contains(file.value),
    );
    if (listed case Ok(value: Listing(:final files, :final unreadable))) {
      final present = {for (final file in files) file.path};
      bool unknown(RelPath note) =>
          unreadable.any((folder) => note.value.startsWith('${folder.value}/'));
      final before = marks.length;
      marks.removeWhere((note, _) => !present.contains(note) && !unknown(note));
      return marks.length != before;
    }
    return false;
  }

  /// Whether listing must enter [folder] to reach the marks folder.
  static bool _leadsToFolder(RelPath folder) =>
      folder.value == _folder || _folder.startsWith('${folder.value}/');

  static bool _isDeviceFile(RelPath path) =>
      path.value == '$_folder/${path.name}' && path.name.endsWith('.json');
}

final class _MarksFiles implements FileFilter {
  const _MarksFiles();

  @override
  bool includesFolder(RelPath folder) => NoteMarks._leadsToFolder(folder);

  @override
  bool includesFile(RelPath file) => NoteMarks._isDeviceFile(file);
}
