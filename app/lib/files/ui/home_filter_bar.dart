import 'package:flutter/material.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../folders/ui/folder_chips.dart';
import 'file_type_chips.dart';

/// The chips that filter the files grid: a row of folder chips, then a
/// row of file type chips, so a picked type stays in sight; each row
/// scrolls sideways when it doesn't fit.
class HomeFilterBar extends StatelessWidget {
  const HomeFilterBar(this.folders, {required this.conflictCount, super.key});

  final List<Folder> folders;

  /// Pending sync conflicts in a folder, shown on its chip.
  final int Function(Folder folder) conflictCount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ChipRow(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: FolderChips(folders, conflictCount: conflictCount),
      ),
      const _ChipRow(
        padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: FileTypeChips(),
      ),
    ],
  );
}

/// One row of chips, scrolling sideways when it doesn't fit.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: padding,
    child: child,
  );
}
