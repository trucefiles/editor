import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../note_text_size.dart';
import '../note_text_size_controller.dart';

/// Settings row with how large notes' text shows: a slider over the
/// sizes there are.
class NoteTextSizeTile extends ConsumerWidget {
  const NoteTextSizeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(noteTextSizeProvider).value;
    return ListTile(
      title: const Text('Text size in notes'),
      trailing: Text(size?.toString() ?? ''),
      subtitle: Slider(
        value: (size ?? NoteTextSize.normal).percent.toDouble(),
        min: NoteTextSize.min.toDouble(),
        max: NoteTextSize.max.toDouble(),
        divisions: (NoteTextSize.max - NoteTextSize.min) ~/ NoteTextSize.step,
        label: size?.toString(),
        onChanged: size == null
            ? null
            : (percent) => ref
                  .read(noteTextSizeProvider.notifier)
                  .set(NoteTextSize.closestTo(percent)),
      ),
    );
  }
}
