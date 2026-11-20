import 'package:truce_files/truce_files.dart';

import 'text_file_contract.dart';

/// The file owner's state: where the file stands, the edits it holds
/// ([text] at the editor's [rev]), and the [file]'s version the edits go
/// over: as last read, written or picked, or the copy a move left;
/// `null` while a new file has no file. The one answer to where the
/// file is.
final class TextFileState<V extends Version> {
  const TextFileState({
    required this.status,
    required this.text,
    required this.rev,
    required this.file,
  });

  final TextFileStatus<V> status;
  final String text;
  final int rev;
  final V? file;

  TextFileState<V> copyWith({
    TextFileStatus<V>? status,
    String? text,
    int? rev,
  }) => TextFileState(
    status: status ?? this.status,
    text: text ?? this.text,
    rev: rev ?? this.rev,
    file: file,
  );

  @override
  bool operator ==(Object other) =>
      other is TextFileState &&
      other.status == status &&
      other.text == text &&
      other.rev == rev &&
      other.file == file;

  @override
  int get hashCode => Object.hash(status, text, rev, file);
}
