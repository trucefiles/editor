import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import '../../alerts/planner_role.dart';

/// The planner's role on Android, where the app and its background check
/// may run at once in one process: a port registered under one name
/// (registering is atomic within the process). The holder answers a ping
/// and plans again when asked; a name whose holder doesn't answer within
/// [_answerWithin] is stale (its isolate ended without giving it up) and
/// is taken over. The wait is long, as a busy holder (reading a large
/// calendar) answers late: two planners at once would give one number to
/// two alerts.
final class IsolatePlannerRole implements PlannerRole {
  static const _name = 'io.github.trucefiles.editor/alert_planner';
  static const _answerWithin = Duration(seconds: 15);

  /// How often a waiting app asks again.
  static const _askEvery = Duration(seconds: 1);

  ReceivePort? _port;

  @override
  Future<void> take({required void Function() onAsked}) async {
    while (!_tryTake(onAsked)) {
      await _askHolder(_Ask.ping);
      await Future<void>.delayed(_askEvery);
    }
  }

  @override
  Future<bool> takeOrAsk() async {
    if (_tryTake(() {})) return true;
    if (await _askHolder(_Ask.planAgain)) return false;
    return _tryTake(() {});
  }

  @override
  void release() {
    final port = _port;
    if (port == null) return;
    if (IsolateNameServer.lookupPortByName(_name) == port.sendPort) {
      IsolateNameServer.removePortNameMapping(_name);
    }
    port.close();
    _port = null;
  }

  bool _tryTake(void Function() onAsked) {
    final port = ReceivePort();
    if (!IsolateNameServer.registerPortWithName(port.sendPort, _name)) {
      port.close();
      return false;
    }
    port.listen((message) {
      if (message case [final String ask, final SendPort reply]) {
        if (ask == _Ask.planAgain.name) onAsked();
        reply.send(true);
      }
    });
    _port = port;
    return true;
  }

  /// Asks the holder [ask]; whether it answered in time. One that
  /// doesn't is stale: its name is dropped, unless another took it
  /// meanwhile.
  Future<bool> _askHolder(_Ask ask) async {
    final holder = IsolateNameServer.lookupPortByName(_name);
    if (holder == null) return false;
    final reply = ReceivePort();
    try {
      holder.send([ask.name, reply.sendPort]);
      final answered = await reply.first.timeout(
        _answerWithin,
        onTimeout: () => false,
      ) as bool;
      if (!answered && IsolateNameServer.lookupPortByName(_name) == holder) {
        IsolateNameServer.removePortNameMapping(_name);
      }
      return answered;
    } finally {
      reply.close();
    }
  }
}

enum _Ask { ping, planAgain }
