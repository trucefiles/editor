import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../common/store_error_text.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import 'unreachable_wait.dart';

/// A compare screen's body: tells when [folder] can't be reached, and
/// shows what [shown] holds: a spinner while it loads, why loading
/// failed, else the [chooser] for its sides; busy while a keep runs or the
/// folder can't be reached.
class CompareBody<Target, Sides> extends ConsumerWidget {
  const CompareBody({
    required this.folder,
    required this.shown,
    required this.chooser,
    super.key,
  });

  final Folder folder;
  final CompareState<Target, Sides> shown;
  final Widget Function(Sides sides, {required bool busy}) chooser;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      UnreachableBanner(folder, message: waitMessage),
      Expanded(
        child: switch (shown) {
          CompareLoading() => const Center(child: CircularProgressIndicator()),
          CompareLoadFailed(:final error) => Center(child: Text(error.text)),
          CompareShowing(:final sides) => chooser(
            sides,
            busy:
                ref.watch(folderReachProvider(folder.id)) == Reach.unreachable,
          ),
          CompareKeeping(:final sides) ||
          CompareDone(:final sides) => chooser(sides, busy: true),
        },
      ),
    ],
  );
}
