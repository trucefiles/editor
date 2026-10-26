import 'file_contract.dart';

/// The file owner's state: where the document stands, and the edits it
/// holds ([text] at the editor's [rev]).
final class FileState {
  const FileState({
    required this.status,
    required this.text,
    required this.rev,
  });

  final FileStatus status;
  final String text;
  final int rev;

  FileState copyWith({FileStatus? status, String? text, int? rev}) => FileState(
    status: status ?? this.status,
    text: text ?? this.text,
    rev: rev ?? this.rev,
  );
}
