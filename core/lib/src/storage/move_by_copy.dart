import 'package:logging/logging.dart';

import '../common/result.dart';
import 'file_store.dart';
import 'rel_path.dart';

final _log = Logger('moveByCopy');

/// [FileStore.move] by copying [from] to [to] in [store] and deleting
/// [from] after: a plain rename would overwrite a file that lands at [to]
/// in the meantime. If [from] changed since [ifUnchanged] or went, the
/// delete refuses and the copy is removed again (only if still as
/// created), so nothing is lost or doubled. The delete alone decides
/// whether [from] changed, so a store whose versions hide its own
/// rewrites keeps moving files it rewrote.
Future<Result<FileEntry, StoreError>> moveByCopy(
  FileStore store,
  RelPath from,
  RelPath to, {
  required FileVersion ifUnchanged,
}) async {
  final FileContent content;
  switch (await store.read(from)) {
    case Ok(:final value):
      content = value;
    case Err(:final error):
      return Err(error);
  }
  final FileEntry copy;
  switch (await store.create(to, content.bytes)) {
    case Ok(:final value):
      copy = value;
    case Err(:final error):
      return Err(error);
  }
  switch (await store.delete(from, ifUnchanged: ifUnchanged)) {
    case Ok():
      return Ok(copy);
    case Err(:final error):
      if (await store.delete(to, ifUnchanged: copy.version) case Err(
        error: final left,
      )) {
        _log.warning('Kept the copy $to of $from: removing it failed ($left)');
      }
      return Err(error);
  }
}
