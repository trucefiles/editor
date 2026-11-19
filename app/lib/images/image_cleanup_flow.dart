import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown_images/truce_markdown_images.dart';

import 'image_cleanup.dart';

/// How the user's cleanup of a folder's unused images ended.
sealed class CleanupOutcome {
  const CleanupOutcome();
}

/// No image is unused.
final class NoneUnused extends CleanupOutcome {
  const NoneUnused();
}

/// Nothing was looked for, for [why].
final class CleanupNotRun extends CleanupOutcome {
  const CleanupNotRun(this.why);

  final CleanupRefused why;
}

/// The user kept the unused images.
final class UnusedKept extends CleanupOutcome {
  const UnusedKept();
}

/// [count] images went.
final class UnusedRemoved extends CleanupOutcome {
  const UnusedRemoved(this.count);

  final int count;
}

/// The user's cleanup of [folder]: the unused images are found, the user
/// agrees to how many ([confirm]), then they go.
Future<CleanupOutcome> cleanUpUnusedImages(
  ImageCleanup cleanup,
  FolderId folder, {
  required Future<bool> Function(int count) confirm,
}) async {
  switch (await cleanup.find(folder)) {
    case Err(:final error):
      return CleanupNotRun(error);
    case Ok(value: []):
      return const NoneUnused();
    case Ok(value: final images):
      if (!await confirm(images.length)) return const UnusedKept();
      return UnusedRemoved(await cleanup.remove(folder, images));
  }
}
