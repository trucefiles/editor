import 'package:flutter/widgets.dart';

import '../note_text_size.dart';

/// [child], notes' text, at [size]: on top of the system's own text
/// scaling.
class NoteTextScale extends StatelessWidget {
  const NoteTextScale({required this.size, required this.child, super.key});

  final NoteTextSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: _TimesScaler(MediaQuery.textScalerOf(context), size.factor),
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
