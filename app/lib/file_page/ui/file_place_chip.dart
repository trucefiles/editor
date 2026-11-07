import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../../folders/ui/folder_badge.dart';
import 'edit_file_place.dart';

/// Shows where the open file is, e.g. `Files/inbox/Milk.md`;
/// tapping it asks for another folder, subfolder or name
/// ([editFilePlace]).
class FilePlaceChip extends ConsumerWidget {
  const FilePlaceChip(this.session, {required this.enabled, super.key});

  final FileSession session;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = session.file;
    return Tooltip(
      message: placeLabel,
      child: ActionChip(
        label: FolderBadge(file.folder, file: session.path, withName: true),
        onPressed: enabled ? () => editFilePlace(context, ref, session) : null,
      ),
    );
  }
}

/// What the chip and the file's menu call the file's place.
const placeLabel = 'Location and name';
