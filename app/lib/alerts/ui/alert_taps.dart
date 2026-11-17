import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/platform_wiring.dart';
import '../alert_tap.dart';
import 'alarm_screen.dart';
import 'open_alert.dart';

/// Answers the alerts the user taps, also the one that started the app:
/// an alarm shows its alarm screen first, any other opens its event or
/// task on its calendar's page; both on [navigator], the window shown
/// first if it was in the tray.
class AlertTaps extends ConsumerStatefulWidget {
  const AlertTaps({required this.navigator, required this.child, super.key});

  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  ConsumerState<AlertTaps> createState() => _AlertTapsState();
}

class _AlertTapsState extends ConsumerState<AlertTaps> {
  late final StreamSubscription<AlertTap> _taps;

  @override
  void initState() {
    super.initState();
    final taps = ref.read(alertTapsProvider);
    _taps = taps.taps.listen(_answer);
    unawaited(
      taps.launch().then((tap) {
        if (tap != null) _answer(tap);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_taps.cancel());
    super.dispose();
  }

  void _answer(AlertTap tap) {
    final navigator = widget.navigator.currentState;
    if (!mounted || navigator == null) return;
    // In the tray, the window shows first.
    if (ref.read(systemTrayProvider) != null) {
      unawaited(ref.read(appWindowProvider).show());
    }
    final controls = ref.read(alarmControlsProvider);
    if (tap.shown == AlertShown.alarm && controls != null) {
      unawaited(
        navigator
            .push(
              MaterialPageRoute<bool>(
                builder: (_) => AlarmScreen(tap, controls: controls),
              ),
            )
            .then((open) async {
              if ((open ?? false) && mounted) {
                await openAlert(navigator.context, ref, tap.alert);
              }
            }),
      );
    } else {
      unawaited(openAlert(navigator.context, ref, tap.alert));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
