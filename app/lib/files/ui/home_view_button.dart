import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../../settings/device_settings_controller.dart';
import '../home_view.dart';

/// App bar button that shows home's view and lets the user pick another;
/// while All shows, also its order and its look.
class HomeViewButton extends ConsumerWidget {
  const HomeViewButton({super.key});

  static IconData _icon(HomeView view) => switch (view) {
    HomeView.home => Icons.home_outlined,
    HomeView.all => Icons.view_module_outlined,
  };

  static String _label(HomeView view) => switch (view) {
    HomeView.home => 'Home',
    HomeView.all => 'All files',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(homeViewProvider);
    final home = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.home),
    );
    final device = ref.read(deviceSettingsProvider.notifier);
    final selected = Theme.of(context).colorScheme.primary;
    PopupMenuItem<VoidCallback> item(
      String label, {
      required bool on,
      required VoidCallback pick,
      IconData? icon,
    }) => PopupMenuItem(
      value: pick,
      child: Row(
        spacing: 12,
        children: [
          Icon(icon ?? (on ? Icons.check : null), color: on ? selected : null),
          Text(label, style: on ? TextStyle(color: selected) : null),
        ],
      ),
    );
    void changeHome(HomeSettings Function(HomeSettings) change) =>
        device.change((s) => s.copyWith(home: change(s.home)));
    return PopupMenuButton<VoidCallback>(
      tooltip: 'View: ${_label(view)}',
      icon: Icon(_icon(view)),
      onSelected: (pick) => pick(),
      itemBuilder: (_) => [
        for (final option in HomeView.values)
          item(
            _label(option),
            icon: _icon(option),
            on: option == view,
            pick: () => ref.read(homeViewProvider.notifier).show(option),
          ),
        if (view == HomeView.all) ...[
          const PopupMenuDivider(),
          item(
            'Newest first',
            on: home.order == FileOrder.time,
            pick: () => changeHome((s) => s.copyWith(order: FileOrder.time)),
          ),
          item(
            'By name',
            on: home.order == FileOrder.name,
            pick: () => changeHome((s) => s.copyWith(order: FileOrder.name)),
          ),
          const PopupMenuDivider(),
          item(
            'As cards',
            on: home.view == FileView.cards,
            pick: () => changeHome((s) => s.copyWith(view: FileView.cards)),
          ),
          item(
            'As list',
            on: home.view == FileView.list,
            pick: () => changeHome((s) => s.copyWith(view: FileView.list)),
          ),
        ],
      ],
    );
  }
}
