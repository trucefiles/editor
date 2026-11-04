import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/clear_chip.dart';
import '../../file_types/file_types.dart';
import '../file_type_selection.dart';

/// One chip per file type the app handles, by the type's icon and name;
/// picks the types the grid shows, none picked showing all; a Clear chip
/// first while some are picked.
class FileTypeChips extends ConsumerWidget {
  const FileTypeChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(pickedFileTypesProvider);
    final picks = ref.read(pickedFileTypesProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (picked.isNotEmpty) ClearChip(onPressed: picks.clear),
        for (final type in ref.watch(fileTypesProvider).all)
          FilterChip(
            showCheckmark: false,
            avatar: Icon(type.icon),
            label: Text(type.name),
            selected: picked.contains(type.support.type),
            onSelected: (_) => picks.toggle(type.support.type),
          ),
      ],
    );
  }
}
