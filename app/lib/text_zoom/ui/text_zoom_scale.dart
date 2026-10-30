import 'package:flutter/widgets.dart';

import '../text_zoom.dart';

/// [child] with its text at [zoom], on top of the system's own text
/// scaling. Another [TextZoomScale] inside it replaces this zoom instead
/// of adding to it, e.g. document text inside the app's text.
class TextZoomScale extends StatelessWidget {
  const TextZoomScale({required this.zoom, required this.child, super.key});

  final TextZoom zoom;
  final Widget child;

  /// The text scaling a [TextZoomScale] at [zoom] gives its child here.
  static TextScaler scalerFor(BuildContext context, TextZoom zoom) =>
      _TimesScaler(_systemOf(context), zoom.factor);

  static TextScaler _systemOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SystemScaler>()?.scaler ??
      MediaQuery.textScalerOf(context);

  @override
  Widget build(BuildContext context) => _SystemScaler(
    _systemOf(context),
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: scalerFor(context, zoom)),
      child: child,
    ),
  );
}

/// The system's text scaling, for zooms inside the outermost one.
class _SystemScaler extends InheritedWidget {
  const _SystemScaler(this.scaler, {required super.child});

  final TextScaler scaler;

  @override
  bool updateShouldNotify(_SystemScaler oldWidget) =>
      oldWidget.scaler != scaler;
}

/// [base] scaling, then [factor] times as large.
@immutable
final class _TimesScaler extends TextScaler {
  const _TimesScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @Deprecated('Use scale instead.')
  @override
  double get textScaleFactor => scale(1);

  @override
  bool operator ==(Object other) =>
      other is _TimesScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
