import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

import '../../common/time_texts.dart';
import '../alarm_controls.dart';
import '../alert_tap.dart';
import '../alert_texts.dart';

/// An alert ringing as an alarm, full screen and over the lock screen:
/// its title and time, with Snooze and Dismiss, and Open to see it on its
/// calendar. Each stops the ringing and closes the screen, which returns
/// `true` if the user asked to open the alert.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen(this.alarm, {required this.controls, super.key});

  final AlertTap alarm;
  final AlarmControls controls;

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controls.showOverLock(show: true));
  }

  @override
  void dispose() {
    unawaited(widget.controls.showOverLock(show: false));
    super.dispose();
  }

  /// Stops the ringing as [act] says and closes, telling whether to
  /// open the alert.
  Future<void> _close(Future<void> Function() act, {bool open = false}) async {
    await act();
    if (mounted) Navigator.of(context).pop(open);
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alarm.alert;
    final texts = Theme.of(context).textTheme;
    // Back is Dismiss: the screen never closes with the alarm ringing on.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_close(() => widget.controls.stop(widget.alarm)));
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: PageWidth(
            builder: (_, padding) => Padding(
              padding: padding.add(const EdgeInsets.all(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Icon(
                    Icons.alarm,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    alertTitle(alert),
                    style: texts.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alertWhen(alert, ref.watch(timeTextsProvider)),
                    style: texts.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () =>
                        _close(() => widget.controls.stop(widget.alarm)),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () =>
                        _close(() => widget.controls.snooze(widget.alarm)),
                    child: const Text('Snooze 10 min'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _close(
                      () => widget.controls.stop(widget.alarm),
                      open: true,
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
