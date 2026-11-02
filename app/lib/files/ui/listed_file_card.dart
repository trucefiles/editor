import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import 'file_card.dart';
import 'file_grid.dart';
import 'listed_file.dart';
import 'pin_or_color_sheet.dart';

/// The card of a listed [file] in a file grid; opens it on tap.
class ListedFileCard extends ConsumerWidget {
  const ListedFileCard(this.file, {super.key});

  final ListedFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:preview, :mark, :settings, :hasConflict) = watchListed(ref, file);
    return gridCard(
      ready: preview is! PreviewReading,
      FileCard(
        file,
        preview: preview,
        mark: mark,
        settings: settings,
        hasConflict: hasConflict,
        onTap: () => openFile(context, ref, file),
        onMark: () => editPinOrColor(context, ref, file),
      ),
    );
  }
}
