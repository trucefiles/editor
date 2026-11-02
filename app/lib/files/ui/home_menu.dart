import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../about/ui/about_menu_item.dart';
import '../../backups/ui/backups_screen.dart';
import '../../settings/ui/settings_screen.dart';

/// The home screen's app bar menu: settings, backups and About.
class HomeMenu extends ConsumerWidget {
  const HomeMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      PopupMenuButton<VoidCallback>(
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: () => openSettings(context),
            child: const Text('Settings'),
          ),
          PopupMenuItem(
            value: () => openBackups(context),
            child: const Text('Backups'),
          ),
          aboutMenuItem(context, ref),
        ],
      );
}
