import 'package:flutter/material.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../folders/ui/folder_chips.dart';
import 'file_type_chips.dart';

/// The chips that filter the files grid: by folder, then by file type;
/// scrolls sideways when they don't fit.
class FileFilterBar extends StatelessWidget {
  const FileFilterBar(this.folders, {required this.conflictCount, super.key});

  final List<Folder> folders;

  /// Pending sync conflicts in a folder, shown on its chip.
  final int Function(Folder folder) conflictCount;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        FolderChips(folders, conflictCount: conflictCount),
        const SizedBox(height: 32, child: VerticalDivider(width: 24)),
        const FileTypeChips(),
      ],
    ),
  );
}
