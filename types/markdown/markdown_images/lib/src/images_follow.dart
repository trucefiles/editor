import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart' show Relink;

import 'document_image_store.dart';
import 'image_names.dart';

/// Where a document is: its folder, and the subfolder it is in (`null`:
/// the top level).
typedef DocumentPlace = ({FolderId folder, RelPath? documentFolder});

/// The one rule for a document's images as it goes [from] one place [to]
/// another (each folder's images are [storeOf]'s): the images of ours it
/// links ([names]) come along into [to]'s folder first, if it is another;
/// then how its links change so each leads from [to], `null` if none
/// must. Fails if they can't come along: its links then stay.
Future<Result<Relink?, StoreError>> imagesFollow(
  Set<String> names, {
  required DocumentPlace from,
  required DocumentPlace to,
  required DocumentImageStore Function(FolderId folder) storeOf,
}) async {
  if (names.isEmpty) return const Ok(null);
  final target = storeOf(to.folder);
  if (to.folder != from.folder) {
    final copied = await storeOf(from.folder).copyInto(target, names);
    if (copied case Err(:final error)) return Err(error);
  }
  if (ImageNames.linksAlike(from.documentFolder, to.documentFolder)) {
    return const Ok(null);
  }
  return target.relinkFrom(to.documentFolder);
}
