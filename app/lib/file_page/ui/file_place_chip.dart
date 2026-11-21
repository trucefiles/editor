import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../folders/ui/folder_badge.dart';

/// Shows where an open file is, the file at [path] in [folder], e.g.
/// `Files/inbox/Milk.md`; tapping it asks for another folder, subfolder
/// or name ([onPressed]; `null` while it can't change).
class FilePlaceChip extends StatelessWidget {
  const FilePlaceChip(
    this.folder,
    this.path, {
    required this.onPressed,
    super.key,
  });

  final Folder folder;
  final RelPath path;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: placeLabel,
    child: ActionChip(
      label: FolderBadge(folder, file: path, withName: true),
      onPressed: onPressed,
    ),
  );
}

/// What the chip and the file's menu call the file's place.
const placeLabel = 'Location and name';
