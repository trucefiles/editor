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

  /// The marks files of all devices, as [known] holds them, with those
  /// that are new or changed since read again, and those gone left out.
  /// Keeps what [known] holds of a file that can't be read now; skips one
  /// never read.
  Future<Result<MarksFiles, StoreError>> load({MarksFiles? known}) async =>
      switch (await _store.list(
        enterFolder: files.includesFolder,
        includeFile: files.includesFile,
      )) {
        Ok(:final value) => Ok(await loadListed(value.files, known: known)),
        Err(:final error) => Err(error),
      };

  /// As [load], from [entries]: the marks files a listing just found
  /// (e.g. one that listed [files] along with the documents).
  Future<MarksFiles> loadListed(
    List<FileEntry> entries, {
    MarksFiles? known,
  }) async {
    final last = known ?? MarksFiles.none;
    return MarksFiles({
      for (final entry in entries)
        entry.path: ?switch (last.files[entry.path]) {
          final read? when read.version == entry.version => read,
          final read => await _read(entry.path) ?? read,
        },
    });
  }

  /// The mark of [document] as all devices' files hold it now. Reads
  /// only the marks files of its own directory.
  Future<Result<DocumentMark, StoreError>> markOf(RelPath document) async {
    final marksFolder = _inDirectory(document.parent, '$_folder/$_marks')!;
    final listed = await _store.list(
      enterFolder: (folder) =>
          folder == marksFolder ||
          marksFolder.value.startsWith('${folder.value}/'),
      includeFile: (file) => file.parent == marksFolder && _isDeviceFile(file),
    );
    return switch (listed) {
      Ok(:final value) => Ok(
        (await loadListed(value.files)).marks[document] ?? DocumentMark.none,
      ),
      Err(:final error) => Err(error),
    };
  }

  /// [known] with the marks files at [paths] read again, e.g. as they
  /// changed: a file that is gone is left out; one that can't be read now
  /// keeps what [known] holds of it.
  Future<MarksFiles> reload(MarksFiles known, Set<RelPath> paths) async {
    final read = {
      for (final path in paths.where(files.includesFile))
        path: await _store.read(path),
    };
    return MarksFiles({
      for (final MapEntry(:key, :value) in known.files.entries)
        if (!read.containsKey(key)) key: value,
      for (final MapEntry(key: path, value: result) in read.entries)
        path: ?switch (result) {
          Ok(:final value) => _decoded(value) ?? known.files[path],
          Err(error: StoreError.notFound) => null,
          Err() => known.files[path],
        },
    });
  }

  /// The marks file at [path]; `null` if it can't be read as one.
  Future<ReadMarksFile?> _read(RelPath path) async =>
      switch (await _store.read(path)) {
        Ok(:final value) => _decoded(value),
        Err() => null,
      };

  static ReadMarksFile? _decoded(FileContent content) =>
      switch (DocumentMarksFile.decode(content.bytes)) {
        final marks? => (version: content.version, marks: marks),
        null => null,
      };

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

/// One device's marks file as read: its version and its marks, by
/// document name in its directory.
typedef ReadMarksFile = ({FileVersion version, Map<String, StampedMark> marks});

/// The marks files of all devices in a base folder, as read, by path;
/// see [DocumentMarks].
final class MarksFiles {
  MarksFiles(this.files);

  static final none = MarksFiles(const {});

  final Map<RelPath, ReadMarksFile> files;

  /// The marked documents, per document the newest mark of all devices;
  /// unmarked ones are left out.
  late final Map<RelPath, DocumentMark> marks = () {
    final newest = <RelPath, StampedMark>{};
    for (final MapEntry(key: path, value: file) in files.entries) {
      final directory = DocumentMarks._directoryOf(path);
      file.marks.forEach((name, stamped) {
        final document = DocumentMarks._inDirectory(directory, name);
        if (document == null) return;
        final known = newest[document];
        if (known == null || stamped.changed.isAfter(known.changed)) {
          newest[document] = stamped;
        }
      });
    }
    return {
      for (final MapEntry(:key, :value) in newest.entries)
        if (!value.mark.isNone) key: value.mark,
    };
  }();
}
