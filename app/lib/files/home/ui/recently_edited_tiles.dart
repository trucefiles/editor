import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../../../common/choice_dialog.dart';
import '../../../settings/device_settings_controller.dart';

/// Settings row with how many files Recently edited shows at most;
/// tapping it asks for another number.
class RecentCountTile extends ConsumerWidget {
  const RecentCountTile({super.key});

  static const _title = 'Recently edited on home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.home.recentCount),
    );
    return ListTile(
      title: const Text(_title),
      subtitle: Text('Up to $count files'),
      onTap: () async {
        final chosen = await showChoiceDialog(
          context,
          title: _title,
          choices: HomeSettings.recentCounts,
          labelOf: (count) => '$count',
          current: count,
        );
        if (chosen case (final count,)) {
          await _changeHome(ref, (home) => home.copyWith(recentCount: count));
        }
      },
    );
  }
}

/// Settings row with how old the files in Recently edited may be;
/// tapping it asks for another age limit.
class RecentAgeTile extends ConsumerWidget {
  const RecentAgeTile({super.key});

  static const _title = 'How old recently edited files can be';

  static String _label(int? days) => switch (days) {
    null => 'No limit',
    final days => 'Up to $days days',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.home.recentDays),
    );
    return ListTile(
      title: const Text(_title),
      subtitle: Text(_label(days)),
      onTap: () async {
        final chosen = await showChoiceDialog<int?>(
          context,
          title: _title,
          choices: [null, ...HomeSettings.recentDayLimits],
          labelOf: _label,
          current: days,
        );
        if (chosen case (final days,)) {
          await _changeHome(ref, (home) => home.withRecentDays(days));
        }
      },
    );
  }
}

Future<void> _changeHome(
  WidgetRef ref,
  HomeSettings Function(HomeSettings home) change,
) => ref
    .read(deviceSettingsProvider.notifier)
    .change((settings) => settings.copyWith(home: change(settings.home)));
