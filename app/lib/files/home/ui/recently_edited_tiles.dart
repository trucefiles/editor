import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../../../common/choice_tile.dart';
import '../../../settings/device_settings_controller.dart';

/// Settings row with how many files Recently edited shows at most.
class RecentCountTile extends ConsumerWidget {
  const RecentCountTile({super.key});

  static const _title = 'Recently edited: how many';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.home.recentCount),
    );
    return ChoiceTile(
      title: _title,
      subtitle: 'Up to $count files',
      choices: HomeSettings.recentCounts,
      labelOf: (count) => '$count',
      current: count,
      onChosen: (count) =>
          _changeHome(ref, (home) => home.copyWith(recentCount: count)),
    );
  }
}

/// Settings row with how old the files in Recently edited may be.
class RecentAgeTile extends ConsumerWidget {
  const RecentAgeTile({super.key});

  static const _title = 'Recently edited: how far back';

  static String _label(int? days) => switch (days) {
    null => 'No limit',
    final days => 'Last $days days',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.home.recentDays),
    );
    return ChoiceTile<int?>(
      title: _title,
      subtitle: _label(days),
      choices: [null, ...HomeSettings.recentDayLimits],
      labelOf: _label,
      current: days,
      onChosen: (days) => _changeHome(ref, (home) => home.withRecentDays(days)),
    );
  }
}

Future<void> _changeHome(
  WidgetRef ref,
  HomeSettings Function(HomeSettings home) change,
) => ref
    .read(deviceSettingsProvider.notifier)
    .change((settings) => settings.copyWith(home: change(settings.home)));
