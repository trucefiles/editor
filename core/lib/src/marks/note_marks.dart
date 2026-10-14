import '../common/result.dart';
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
/// its mark, and marks of deleted notes stay unused in the files.
final class NoteMarks {
  /// [deviceId] must be unique per device and a valid file name.
  NoteMarks(this._store, {required String deviceId, DateTime Function()? now})
    : _ownFile = RelPath.parse('$_folder/$deviceId.json')!,
      _now = now ?? DateTime.now;

  static const _folder = '.truce/marks';

  final FileStore _store;
  final RelPath _ownFile;
  final DateTime Function() _now;

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
  /// writing over the marks in it.
  Future<Result<void, StoreError>> set(RelPath note, NoteMark mark) async {
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
    marks[note] = (mark: mark, changed: _now());
    final bytes = NoteMarksFile.encode(marks);
    final written = version == null
        ? await _store.create(_ownFile, bytes)
        : await _store.replace(_ownFile, bytes, ifUnchanged: version);
    return switch (written) {
      Ok() => const Ok(null),
      Err(:final error) => Err(error),
    };
  }

  /// Whether listing must enter [folder] to reach the marks folder.
  static bool _leadsToFolder(RelPath folder) =>
      folder.value == _folder || _folder.startsWith('${folder.value}/');

  static bool _isDeviceFile(RelPath path) =>
      path.value == '$_folder/${path.name}' && path.name.endsWith('.json');
}
