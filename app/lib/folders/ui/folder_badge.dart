import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../note_folder.dart';

/// The folder's color dot and name, so it is always clear where a note
/// lives. With [file], also the subfolders it is in, e.g. `Notes/work/2026`,
/// and with [withName] its name, e.g. `Notes/work/todo.md`; with
/// [subfolder], that subfolder.
class FolderBadge extends StatelessWidget {
  const FolderBadge(
    this.folder, {
    this.file,
    this.withName = false,
    this.subfolder,
    super.key,
  });

  final NoteFolder folder;

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

/// [folder]'s name, followed by [subfolder] if given, e.g. `Notes/work`.
String placeName(NoteFolder folder, RelPath? subfolder) => switch (subfolder) {
  final subfolder? => '${folder.name}/${subfolder.value}',
  null => folder.name,
};

class FolderDot extends StatelessWidget {
  const FolderDot(this.color, {super.key, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
