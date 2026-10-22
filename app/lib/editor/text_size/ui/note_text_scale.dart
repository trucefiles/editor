import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../note_text_size.dart';
import '../note_text_size_controller.dart';

/// [child], notes' text, as large as chosen on this device: on top of the
/// system's own text scaling.
class NoteTextScale extends ConsumerWidget {
  const NoteTextScale({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(noteTextSizeProvider).value ?? NoteTextSize.normal;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: _TimesScaler(MediaQuery.textScalerOf(context), size.factor),
      ),
      child: child,
    );
  }
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
