import 'package:flutter/material.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../folder_colors.dart';

/// The folder's color dot and name, so it is always clear where a file
/// lives. With [file], also the subfolders it is in, e.g. `Files/work/2026`,
/// and with [withName] its name, e.g. `Files/work/todo.md`; with
/// [subfolder], that subfolder. The full place shows on hover. Where the
/// place doesn't fit, it ends in "…"; with [cutInMiddle], it is cut in the
/// middle instead (see [placeNames]), which needs a parent that gives it
/// a width (not a chip or a menu, which ask for its size first).
class FolderBadge extends StatelessWidget {
  const FolderBadge(
    this.folder, {
    this.file,
    this.withName = false,
    this.subfolder,
    this.cutInMiddle = false,
    super.key,
  });

  final Folder folder;

  /// A file in [folder].
  final RelPath? file;

  final bool withName;

  /// A subfolder of [folder], shown if there is no [file].
  final RelPath? subfolder;

  final bool cutInMiddle;

  @override
  Widget build(BuildContext context) {
    final names = switch (file) {
      final file? when withName => placeNames(folder, file),
      _ => placeNames(folder, file?.parent ?? subfolder),
    };
    final style = Theme.of(context).textTheme.labelSmall;
    return Tooltip(
      message: names.first,
      // Only on hover: a long press belongs to what the badge sits on.
      triggerMode: TooltipTriggerMode.manual,
      child: cutInMiddle
          ? LayoutBuilder(
              builder: (context, constraints) =>
                  switch (constraints.maxWidth - _dotSize - _dotGap) {
                    // Not even the dot fits.
                    < 0 => const SizedBox.shrink(),
                    final width => _row(
                      firstFitting(
                        names,
                        width: width,
                        style: style,
                        context: context,
                      ),
                      style,
                    ),
                  },
            )
          : _row(names.first, style),
    );
  }

  Widget _row(String place, TextStyle? style) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: _dotGap,
    children: [
      FolderDot(folder.color),
      Flexible(
        child: Text(
          place,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

const _dotSize = 10.0;
const _dotGap = 6.0;

/// [folder]'s name, followed by [subfolder] if given, e.g. `Files/work`.
String placeName(Folder folder, RelPath? subfolder) => switch (subfolder) {
  final subfolder? => '${folder.name}/${subfolder.value}',
  null => folder.name,
};

/// The ways to show [path] in [folder], longest first: the full place
/// (as [placeName]), then cut in the middle to the folder's name and the
/// last part (`Shared Notes/…/work`), then the folder's name alone
/// (`Shared Notes/…`). The folder's name is what is cut last.
List<String> placeNames(Folder folder, RelPath? path) => [
  placeName(folder, path),
  if (path case final path? when path.parent != null)
    '${folder.name}/…/${path.name}',
  if (path != null) '${folder.name}/…',
];

class FolderDot extends StatelessWidget {
  const FolderDot(this.color, {super.key, this.size = _dotSize});

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
