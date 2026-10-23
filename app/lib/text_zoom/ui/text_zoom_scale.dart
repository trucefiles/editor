import 'package:flutter/widgets.dart';

import '../text_zoom.dart';

/// [child] with its text at [zoom]: on top of the system's own text
/// scaling.
class TextZoomScale extends StatelessWidget {
  const TextZoomScale({required this.zoom, required this.child, super.key});

  final TextZoom zoom;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: _TimesScaler(MediaQuery.textScalerOf(context), zoom.factor),
    ),
    child: child,
  );
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
