/// How an open file's page writes new files and moves its file, as
/// the files owner does (see `FileSteps`).
library;

import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import 'file_bytes.dart';
import 'file_place.dart';
import 'move_failure.dart';

/// Creates a file holding [bytes] at [place], named after [title] with
/// [extension]; first [place]'s subfolder if it is new ([newSubfolder]).
typedef FileCreator = Future<Result<FileBytes, StoreError>> Function(
  FilePlace place, {
  required String extension,
  required String title,
  required Uint8List bytes,
  bool newSubfolder,
});

/// Moves a file, as last saved, to [place], named after
/// [title]; first [place]'s subfolder if it is new ([newSubfolder]).
typedef FileMover = Future<Result<FileBytes, MoveFailure>> Function(
  FileBytes file,
  FilePlace place, {
  required String title,
  required bool newSubfolder,
});
