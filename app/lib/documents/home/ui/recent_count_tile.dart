import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/device_settings_controller.dart';
import '../home_settings.dart';

/// Settings row with how many documents Recent shows besides the pinned
/// ones; tapping it asks for another number.
class RecentCountTile extends ConsumerWidget {
  const RecentCountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.home.recentCount),
    );
    return ListTile(
      title: const Text('Recent documents on home'),
      subtitle: Text('$count'),
      onTap: () async {
        final chosen = await _showRecentCountDialog(context, current: count);
        if (chosen == null) return;
        await ref
            .read(deviceSettingsProvider.notifier)
            .change(
              (settings) => settings.copyWith(
                home: settings.home.copyWith(recentCount: chosen),
              ),
            );
      },
    );
  }
}

/// Lets the user pick how many documents Recent shows; the choice, or
/// `null` if cancelled.
Future<int?> _showRecentCountDialog(
  BuildContext context, {
  required int current,
}) => showDialog<int>(
  context: context,
  builder: (context) => SimpleDialog(
    title: const Text('Recent documents on home'),
    children: [
      RadioGroup<int>(
        groupValue: current,
        onChanged: (choice) => Navigator.pop(context, choice),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final count in HomeSettings.recentCounts)
              RadioListTile(value: count, title: Text('$count')),
          ],
        ),
      ),
    ],
  ),
);
