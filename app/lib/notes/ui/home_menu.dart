import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../refresh/ui/refresh_menu_item.dart';
import '../../tray/ui/close_to_tray_menu.dart';

/// The home screen's app bar menu: app-wide settings.
class HomeMenu extends ConsumerWidget {
  const HomeMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Built here, not when the menu opens, so the settings are watched
    // and loaded by then.
    final items = [refreshMenuItem(context, ref), ...closeToTrayMenuItems(ref)];
    return PopupMenuButton<VoidCallback>(
      onSelected: (action) => action(),
      itemBuilder: (_) => items,
    );
  }
}
