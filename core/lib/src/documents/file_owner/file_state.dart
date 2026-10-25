import 'file_contract.dart';
import 'file_work.dart';

/// The file owner's state: where the document stands, and the edits it
/// holds ([text] at the editor's [rev]).
final class FileState {
  const FileState({
    required this.status,
    required this.text,
    required this.rev,
    required this.work,
  });

  final FileStatus status;
  final String text;
  final int rev;

  /// The owner's own bookkeeping; not for its users.
  final FileWork work;

  FileState copyWith({
    FileStatus? status,
    String? text,
    int? rev,
    FileWork? work,
  }) => FileState(
    status: status ?? this.status,
    text: text ?? this.text,
    rev: rev ?? this.rev,
    work: work ?? this.work,
  );
}
