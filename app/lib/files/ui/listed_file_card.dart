import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import 'file_actions_menu.dart';
import 'file_card.dart';
import 'file_grid.dart';
import 'listed_file.dart';
import 'open_file.dart';

/// The card of a listed [file] in a file grid; opens it on tap.
class ListedFileCard extends ConsumerWidget {
  const ListedFileCard(this.file, {super.key});

  final ListedFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:preview, :mark, :settings, :hasConflict) = watchListed(ref, file);
    return gridCard(
      ready: preview is! PreviewReading,
      HomeFileActions(
        file,
        title: cardTitle(file, preview),
        pinned: settings.pinned,
        color: mark.color,
        builder: (showSheet, showMenuAt) => FileCard(
          file,
          preview: preview,
          mark: mark,
          settings: settings,
          hasConflict: hasConflict,
          onTap: () => openFile(context, ref, file),
          onActions: showSheet,
          onActionsAt: showMenuAt,
        ),
      ),
    );
  }
}
