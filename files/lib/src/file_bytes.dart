import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'listed_file.dart';

/// A file as the app last read or wrote it: the [listed] (where it is,
/// its version) and its [bytes]. Each type reads the bytes its own way
/// (e.g. a text type decodes them). Never changes.
final class FileBytes {
  const FileBytes(this.listed, this.bytes);

  final ListedFile listed;
  final Uint8List bytes;

  Folder get folder => listed.folder;
  RelPath get path => listed.path;
  FileTypeSupport get type => listed.type;
  FileKey get key => listed.key;
}
