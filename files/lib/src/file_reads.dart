import 'package:truce_core/truce_core.dart';

import 'file_text.dart';
import 'files_of_folder.dart';
import 'listed_file.dart';

/// What a set of files read as (e.g. each calendar of the Calendar
/// tab): [readAs] turns a file's text into what is kept of it, `null`
/// if nothing is. A file is read again only once it changes (a new
/// version as listed).
final class FileReads<T extends Object> {
  FileReads(this._files, {required this.readAs});

  final FolderFiles _files;
  final T? Function(FileText read) readAs;

  /// What the last [readAll] read, by key, as the file was listed; a
  /// file that couldn't be read is not here, so it is tried again.
  var _read = <FileKey, ({ListedFile file, T? value})>{};

  /// What each of [listed] reads as, read anew where it changed or its
  /// last read failed; a file that can't be read or reads as nothing is
  /// left out. Keeps only these, so files gone are dropped.
  Future<Map<ListedFile, T>> readAll(List<ListedFile> listed) async {
    final read = {
      for (final file in listed)
        file.key: ?switch (_read[file.key]) {
          final known? when known.file == file => known,
          _ => await _readOf(file),
        },
    };
    _read = read;
    return {for (final file in listed) file: ?read[file.key]?.value};
  }

  /// [file] read now; `null` if it couldn't be read.
  Future<({ListedFile file, T? value})?> _readOf(ListedFile file) async =>
      switch (await _files.of(file.folder).reload(file)) {
        Ok(:final value) => (file: file, value: readAs(value)),
        Err() => null,
      };
}
