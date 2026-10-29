import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'document.dart';

/// A document's file as the app last read or wrote it: the [document] and
/// its text, in its file's byte style ([file]). Held only while the
/// document is open, compared or restored.
@immutable
final class DocumentText {
  const DocumentText(this.document, this.file);

  final Document document;
  final TextFile file;

  String get text => file.text;

  DocumentFolder get folder => document.folder;
  RelPath get path => document.path;
  FileTypeSupport<Object?> get type => document.type;
  DocumentKey get key => document.key;
}
