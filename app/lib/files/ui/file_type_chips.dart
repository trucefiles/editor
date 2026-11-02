import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../file_types/file_types.dart';
import '../file_type_selection.dart';

/// One chip per file type the app handles, by the type's name; picks
/// the type the grid shows. Tapping the picked one again shows every
/// type.
class FileTypeChips extends ConsumerWidget {
  const FileTypeChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFileTypeProvider);
    final selection = ref.read(selectedFileTypeProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final type in ref.watch(fileTypesProvider).all)
          ChoiceChip(
            label: Text(type.name),
            selected: selected == type.support.type,
            onSelected: (picked) =>
                selection.choose(picked ? type.support.type : null),
          ),
      ],
    );
  }
}
