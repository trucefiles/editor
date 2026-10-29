import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../folder_colors.dart';

/// The folder's color dot and name, so it is always clear where a document
/// lives. With [file], also the subfolders it is in, e.g. `Documents/work/2026`,
/// and with [withName] its name, e.g. `Documents/work/todo.md`; with
/// [subfolder], that subfolder.
class FolderBadge extends StatelessWidget {
  const FolderBadge(
    this.folder, {
    this.file,
    this.withName = false,
    this.subfolder,
    super.key,
  });

  final DocumentFolder folder;

  /// A file in [folder].
  final RelPath? file;

  final bool withName;

  /// A subfolder of [folder], shown if there is no [file].
  final RelPath? subfolder;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FolderDot(folder.color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            switch (file) {
              final file? when withName =>
                '${placeName(folder, file.parent)}/${file.name}',
              _ => placeName(folder, file?.parent ?? subfolder),
            },
            style: Theme.of(context).textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// [folder]'s name, followed by [subfolder] if given, e.g. `Documents/work`.
String placeName(DocumentFolder folder, RelPath? subfolder) =>
    switch (subfolder) {
      final subfolder? => '${folder.name}/${subfolder.value}',
      null => folder.name,
    };

class FolderDot extends StatelessWidget {
  const FolderDot(this.color, {super.key, this.size = 10});

  /// The color's name.
  final String color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: folderColor(color),
        shape: BoxShape.circle,
      ),
    );
  }
}
