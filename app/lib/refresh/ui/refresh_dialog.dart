import 'package:flutter/material.dart';

import '../../common/interval_text.dart';
import '../refresh_settings.dart';

/// Lets the user pick how changes from elsewhere show up; the new setting,
/// or `null` if cancelled. Offers live updates only if [liveAvailable].
Future<RefreshSettings?> showRefreshDialog(
  BuildContext context, {
  required RefreshSettings current,
  required bool liveAvailable,
}) => showDialog<RefreshSettings>(
  context: context,
  builder: (_) =>
      _RefreshDialog(current: current, liveAvailable: liveAvailable),
);

class _RefreshDialog extends StatefulWidget {
  const _RefreshDialog({required this.current, required this.liveAvailable});

  final RefreshSettings current;
  final bool liveAvailable;

  @override
  State<_RefreshDialog> createState() => _RefreshDialogState();
}

class _RefreshDialogState extends State<_RefreshDialog> {
  late var _settings = widget.current;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Show changes from other devices'),
    content: RadioGroup<RefreshMode>(
      groupValue: _settings.mode,
      onChanged: (mode) =>
          setState(() => _settings = _settings.copyWith(mode: mode)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.liveAvailable)
            const RadioListTile(
              value: RefreshMode.live,
              title: Text('Live'),
              subtitle: Text(
                'As they happen. Folders where this is not possible are '
                'checked at the interval below.',
              ),
            ),
          const RadioListTile(
            value: RefreshMode.periodic,
            title: Text('Periodic'),
            subtitle: Text('Checks the folders at the interval below.'),
          ),
          const RadioListTile(
            value: RefreshMode.manual,
            title: Text('Manual'),
            subtitle: Text(
              'Only with Refresh or pull-down, when a note opens, or when '
              'you come back to the app.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownMenu<Duration>(
              label: const Text('Interval'),
              initialSelection: _settings.interval,
              enabled: _settings.mode != RefreshMode.manual,
              onSelected: (interval) => setState(
                () => _settings = _settings.copyWith(interval: interval),
              ),
              dropdownMenuEntries: [
                for (final interval in RefreshSettings.intervals)
                  DropdownMenuEntry(
                    value: interval,
                    label: 'Every ${intervalText(interval)}',
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _settings),
        child: const Text('Save'),
      ),
    ],
  );
}
