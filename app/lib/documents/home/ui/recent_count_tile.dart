import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home_settings.dart';
import '../home_settings_controller.dart';

/// Settings row with how many documents Recent shows besides the pinned
/// ones; tapping it asks for another number.
class RecentCountTile extends ConsumerWidget {
  const RecentCountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(homeSettingsProvider).value;
    return ListTile(
      enabled: settings != null,
      title: const Text('Recent documents on home'),
      subtitle: Text(settings == null ? '…' : '${settings.recentCount}'),
      onTap: () async {
        final chosen = await _showRecentCountDialog(
          context,
          current: settings!.recentCount,
        );
        if (chosen == null) return;
        await ref
            .read(homeSettingsProvider.notifier)
            .change((settings) => settings.copyWith(recentCount: chosen));
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
