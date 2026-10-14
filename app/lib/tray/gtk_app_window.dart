import 'dart:ui' show AppExitType;

import 'package:flutter/services.dart';

import 'app_window.dart';

/// The GTK window of the Linux runner (`linux/runner/my_application.cc`).
final class GtkAppWindow implements AppWindow {
  const GtkAppWindow();

  static const _channel = MethodChannel('io.github.trucefiles.editor/window');

  @override
  Future<void> setHideOnClose({required bool hide}) =>
      _channel.invokeMethod<void>('setHideOnClose', hide);

  @override
  Future<void> show() => _channel.invokeMethod<void>('show');

  @override
  Future<void> quit() async {
    // A hidden window could not show the "edits can't be saved" question.
    await show();
    await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
  }
}
