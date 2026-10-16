import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../folder_reach_controller.dart';

/// Blocks all input to [child] while a folder is being reached again, and
/// tells which. Goes over every screen and dialog.
class ReachOverlay extends ConsumerWidget {
  const ReachOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retrying = ref.watch(retryingFoldersProvider);
    final blocked = retrying.isNotEmpty;
    return Stack(
      children: [
        // Keyboard input too: the focused text field loses the focus.
        ExcludeFocus(excluding: blocked, child: child),
        if (blocked) ...[
          const ModalBarrier(dismissible: false, color: Colors.black38),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    const CircularProgressIndicator(),
                    Flexible(
                      child: Text(
                        'Trying to reach '
                        '${retrying.map((folder) => folder.name).join(', ')}…',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
