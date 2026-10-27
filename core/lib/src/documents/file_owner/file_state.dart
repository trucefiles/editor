import '../version.dart';
import 'file_contract.dart';

/// The file owner's state: where the document stands, the edits it holds
/// ([text] at the editor's [rev]), and the [file]'s version the edits go
/// over: as last read, written or picked, or the copy a move left;
/// `null` while a new document has no file.
final class FileState {
  const FileState({
    required this.status,
    required this.text,
    required this.rev,
    required this.file,
  });

  final FileStatus status;
  final String text;
  final int rev;
  final Version? file;

  FileState copyWith({FileStatus? status, String? text, int? rev}) => FileState(
    status: status ?? this.status,
    text: text ?? this.text,
    rev: rev ?? this.rev,
    file: file,
  );

  @override
  bool operator ==(Object other) =>
      other is FileState &&
      other.status == status &&
      other.text == text &&
      other.rev == rev &&
      other.file == file;

  @override
  int get hashCode => Object.hash(status, text, rev, file);
}
