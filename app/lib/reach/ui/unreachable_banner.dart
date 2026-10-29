import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../folder_state/folder_state_controller.dart';
import '../folder_reach_controller.dart';

/// Tells that [folder] can't be reached, with [message] on what that means
/// for the screen, and offers to try again. Shows nothing while it can.
class UnreachableBanner extends ConsumerWidget {
  const UnreachableBanner(this.folder, {required this.message, super.key});

  final DocumentFolder folder;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(folderReachProvider(folder.base)) != Reach.unreachable) {
      return const SizedBox.shrink();
    }
    return MaterialBanner(
      leading: const Icon(Icons.cloud_off_outlined),
      content: Text("${folder.name} can't be reached. $message"),
      actions: [
        TextButton(
          // Any access that works brings the folder back.
          onPressed: ref.read(folderContentsProvider.notifier).refresh,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
