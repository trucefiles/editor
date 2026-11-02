import 'package:logging/logging.dart';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';

final _log = Logger('moveByCopy');

/// Why a move failed.
sealed class MoveError {
  const MoveError();
}

/// Nothing moved, as [error] tells: the file stays where it was.
final class NotMoved extends MoveError {
  const NotMoved(this.error);

  final StoreError error;
}

/// The file was copied to [copy], but the original could not be removed
/// ([error]): both stay, so nothing is lost.
final class CopiedOnly extends MoveError {
  const CopiedOnly(this.copy, this.error);

  final FileEntry copy;
  final StoreError error;
}

/// The shared way to move a file, for any two folders and inside one:
/// copies [from] in [source] to [to] in [target], then deletes [from].
/// Never overwrites a file at [to] ([StoreError.alreadyExists]). If [from]
/// is no longer at version [ifUnchanged], the delete refuses and the copy
/// is removed again (only if still as created): nothing moved, nothing
/// doubled; if the copy can't be removed, both stay ([CopiedOnly]). If the
/// delete fails otherwise, both stay too. The delete alone decides whether
/// [from] changed, so a store whose versions hide its own rewrites keeps
/// moving files it rewrote.
Future<Result<FileEntry, MoveError>> moveByCopy(
  FileStore source,
  RelPath from, {
  required FileVersion ifUnchanged,
  required FileStore target,
  required RelPath to,
}) async {
  final FileContent content;
  switch (await source.read(from)) {
    case Ok(:final value):
      content = value;
    case Err(:final error):
      return Err(NotMoved(error));
  }
  final FileEntry copy;
  switch (await target.create(to, content.bytes)) {
    case Ok(:final value):
      copy = value;
    case Err(:final error):
      return Err(NotMoved(error));
  }
  return switch (await source.delete(from, ifUnchanged: ifUnchanged)) {
    Ok() => Ok(copy),
    Err(error: StoreError.changedSinceRead) => Err(
      await _withoutCopy(target, copy, of: from),
    ),
    Err(:final error) => Err(CopiedOnly(copy, error)),
  };
}

/// Removes [copy] of [of] again, as [of] changed meanwhile: nothing moved;
/// if removing fails, both stay.
Future<MoveError> _withoutCopy(
  FileStore target,
  FileEntry copy, {
  required RelPath of,
}) async {
  switch (await target.delete(copy.path, ifUnchanged: copy.version)) {
    case Ok():
      return const NotMoved(StoreError.changedSinceRead);
    case Err(error: final left):
      _log.warning(
        'Kept the copy ${copy.path} of $of: removing it failed ($left)',
      );
      return CopiedOnly(copy, StoreError.changedSinceRead);
  }
}
