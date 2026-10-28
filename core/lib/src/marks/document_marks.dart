import 'package:pool/pool.dart';

import '../common/result.dart';
import '../filter/file_filter.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'document_mark.dart';
import 'document_marks_file.dart';

/// Colors of the documents in one base folder, kept in the folder itself so
/// they sync with it.
///
/// Each directory that holds marked documents keeps their marks next to
/// them, in `.truce/marks/`, so every device finds them whatever part of
/// the folder it shows. Each device writes only its own file there,
/// `<device id>.json` (see [DocumentMarksFile]), so marks never cause a
/// sync conflict. Reading merges the files of all devices: per document,
/// the newest mark wins.
///
/// Marks are keyed by path: a document renamed or moved outside the app loses
/// its mark. Each write of this device's file also drops the marks of
/// documents that are gone from its directory, so the file never keeps
/// growing. Only writes do: they come from user actions, while a write on
/// its own would sync to every device.
final class DocumentMarks {
  /// [deviceId] must be unique per device and a valid file name.
  DocumentMarks(
    this._store, {
    required String deviceId,
    DateTime Function()? now,
  }) : _ownName = '$deviceId.json',
       _now = now ?? DateTime.now;

  static const _folder = '.truce';
  static const _marks = 'marks';

  /// The files that hold the marks of all devices, e.g. to follow other
  /// devices' changes to them; their folders, and every folder that may
  /// lead to them.
  static const FileFilter files = _MarksFiles();

  final FileStore _store;
  final String _ownName;
  final DateTime Function() _now;

  /// Changes to this device's files, one at a time.
  final _changes = Pool(1);

  /// The marked documents; unmarked ones are left out. Skips device files that
  /// cannot be read.
  Future<Result<Map<RelPath, DocumentMark>, StoreError>> load() async {
    final List<FileEntry> entries;
    switch (await _store.list(
      enterFolder: files.includesFolder,
      includeFile: files.includesFile,
    )) {
      case Ok(:final value):
        entries = value.files;
      case Err(:final error):
        return Err(error);
    }
    final newest = <RelPath, StampedMark>{};
    for (final entry in entries) {
      final directory = _directoryOf(entry.path);
      if (await _store.read(entry.path) case Ok(:final value)) {
        DocumentMarksFile.decode(value.bytes)?.forEach((name, stamped) {
          final document = _inDirectory(directory, name);
          if (document == null) return;
          final known = newest[document];
          if (known == null || stamped.changed.isAfter(known.changed)) {
            newest[document] = stamped;
          }
        });
      }
    }
    return Ok({
      for (final MapEntry(:key, :value) in newest.entries)
        if (!value.mark.isNone) key: value.mark,
    });
  }

  /// Sets the mark of [document] in this device's file of its directory.
  /// Fails with [StoreError.ioFailure] if the file cannot be read as marks,
  /// instead of writing over the marks in it. Runs after every earlier
  /// change, so each starts from the marks the one before wrote.
  Future<Result<void, StoreError>> set(RelPath document, DocumentMark mark) =>
      _changes.withResource(
        () => _change(document.parent, (marks) {
          marks[document.name] = (mark: mark, changed: _now());
          return true;
        }),
      );

  /// Drops the mark of [document] from this device's file, e.g. as the user
  /// deletes it. As [set]; writes nothing if there is nothing to drop.
  Future<Result<void, StoreError>> remove(RelPath document) =>
      _changes.withResource(
        () => _change(
          document.parent,
          (marks) => marks.remove(document.name) != null,
        ),
      );

  /// Applies [apply] to this device's marks of [directory] (`null`: the
  /// base folder's top level) and writes them, without the marks of gone
  /// documents, if [apply] or that changed any.
  Future<Result<void, StoreError>> _change(
    RelPath? directory,
    bool Function(Map<String, StampedMark> marks) apply,
  ) async {
    final ownFile = _inDirectory(directory, '$_folder/$_marks/$_ownName')!;
    final FileVersion? version;
    final Map<String, StampedMark> marks;
    switch (await _store.read(ownFile)) {
      case Ok(:final value):
        version = value.version;
        final decoded = DocumentMarksFile.decode(value.bytes);
        if (decoded == null) return const Err(StoreError.ioFailure);
        marks = decoded;
      case Err(error: StoreError.notFound):
        version = null;
        marks = {};
      case Err(:final error):
        return Err(error);
    }
    final applied = apply(marks);
    final pruned = await _dropGone(directory, marks);
    if (!applied && !pruned) return const Ok(null);
    final bytes = DocumentMarksFile.encode(marks);
    final written = version == null
        ? await _store.create(ownFile, bytes)
        : await _store.replace(ownFile, bytes, ifUnchanged: version);
    return switch (written) {
      Ok() => const Ok(null),
      Err(:final error) => Err(error),
    };
  }

  /// Drops the marks of documents that are no longer in [directory]; keeps
  /// all if it can't be listed. Lists that one directory, no deeper.
  /// Returns whether it dropped any.
  Future<bool> _dropGone(
    RelPath? directory,
    Map<String, StampedMark> marks,
  ) async {
    final listed = await _store.list(
      enterFolder: (folder) =>
          directory != null &&
          (folder == directory ||
              directory.value.startsWith('${folder.value}/')),
      includeFile: (file) =>
          file.parent == directory && marks.containsKey(file.name),
    );
    if (listed case Ok(value: Listing(:final files, :final unreadable))
        when unreadable.isEmpty) {
      final present = {for (final file in files) file.path.name};
      final before = marks.length;
      marks.removeWhere((name, _) => !present.contains(name));
      return marks.length != before;
    }
    return false;
  }

  /// The directory whose documents the marks file at [path] holds;
  /// `null` for the base folder's top level.
  static RelPath? _directoryOf(RelPath path) => path.parent!.parent!.parent;

  static RelPath? _inDirectory(RelPath? directory, String name) =>
      directory == null
      ? RelPath.parse(name)
      : RelPath.parse('${directory.value}/$name');

  /// Whether [folder] is a marks folder, or lies on the way to one: a
  /// visible folder, `.truce` in one, or `marks` in that.
  static bool _mayLeadToMarks(RelPath folder) {
    final segments = folder.value.split('/');
    final hidden = segments.indexWhere((segment) => segment.startsWith('.'));
    return switch (hidden) {
      -1 => true,
      final at when segments[at] == _folder =>
        segments.length == at + 1 ||
            (segments.length == at + 2 && segments[at + 1] == _marks),
      _ => false,
    };
  }

  static bool _isDeviceFile(RelPath path) {
    final marks = path.parent;
    return path.name.endsWith('.json') &&
        marks?.name == _marks &&
        marks?.parent?.name == _folder &&
        _mayLeadToMarks(marks!);
  }
}

final class _MarksFiles implements FileFilter {
  const _MarksFiles();

  @override
  bool includesFolder(RelPath folder) => DocumentMarks._mayLeadToMarks(folder);

  @override
  bool includesFile(RelPath file) => DocumentMarks._isDeviceFile(file);
}
