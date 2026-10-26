import '../../owners/owner.dart';
import '../version.dart';
import 'file_contract.dart';
import 'file_state.dart';
import 'file_transition.dart';
import 'file_work.dart';

export 'file_contract.dart';
export 'file_state.dart' show FileState;

/// The owner of one open document's file (see `file_contract.dart`).
typedef FileOwner = Owner<FileInput, FileState, FileOutput>;

/// The file owner of a document opened as [opened].
FileOwner openedFileOwner(Seen opened) => _owner(
  FileState(status: const InStep(), text: opened.text, rev: 0),
  FileWork(expected: opened, offered: [opened]),
);

/// The file owner of a new document, which has no file yet.
FileOwner newFileOwner() => _owner(
  const FileState(status: Unwritten(), text: '', rev: 0),
  const FileWork(expected: null, offered: []),
);

FileOwner _owner(FileState state, FileWork work) =>
    TransitionOwner(state, work, fileStep);
