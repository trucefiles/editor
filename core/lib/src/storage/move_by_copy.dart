import '../common/result.dart';
import 'file_store.dart';
import 'rel_path.dart';

/// [FileStore.move] by copying [from] to [to] in [store] and deleting
/// [from] after: a plain rename would overwrite a file that lands at [to]
/// in the meantime. If [from] changed or went meanwhile, the copy is
/// removed again (only if still as created), so nothing is lost or
/// doubled.
Future<Result<FileEntry, StoreError>> moveByCopy(
  FileStore store,
  RelPath from,
  RelPath to, {
  required FileVersion ifUnchanged,
}) async {
  final FileContent content;
  switch (await store.read(from)) {
    case Ok(:final value) when value.version == ifUnchanged:
      content = value;
    case Ok():
      return const Err(StoreError.changedSinceRead);
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
      await store.delete(to, ifUnchanged: copy.version);
      return Err(error);
  }
}
