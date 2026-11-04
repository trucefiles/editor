import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../../folders/ui/folder_badge.dart';
import '../file_actions.dart';
import '../file_settings_controller.dart';
import 'color_circles.dart';
import 'file_choice.dart';

/// A file's actions on home: on a long press as a sheet, on a right
/// click as a menu at the pointer. Open, pin and color are here; the
/// rest is on the file's page, which both say. [builder] gets the two
/// ways to show them.
class HomeFileActions extends ConsumerStatefulWidget {
  const HomeFileActions(
    this.file, {
    required this.title,
    required this.pinned,
    required this.color,
    required this.builder,
    super.key,
  });

  final ListedFile file;

  /// The file's title, as its card shows it.
  final String title;

  final bool pinned;
  final String? color;

  final Widget Function(VoidCallback showSheet, ValueChanged<Offset> showMenuAt)
  builder;

  @override
  ConsumerState<HomeFileActions> createState() => _HomeFileActionsState();
}

class _HomeFileActionsState extends ConsumerState<HomeFileActions> {
  final _menu = MenuController();

  Future<void> _apply(FileChoice choice) =>
      applyFileChoice(context, ref, widget.file, choice);

  Future<void> _showSheet() async {
    final choice = await _showFileSheet(
      context,
      header: (
        title: widget.title,
        place: placeName(widget.file.folder, widget.file.path.parent),
      ),
      pinned: widget.pinned,
      color: widget.color,
    );
    if (choice != null && mounted) await _apply(choice);
  }

  /// Opens the menu at [position], a point on the screen.
  void _showMenuAt(Offset position) {
    final box = context.findRenderObject()! as RenderBox;
    _menu.open(position: box.globalToLocal(position));
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    menuChildren: _menuItems(context),
    child: widget.builder(_showSheet, _showMenuAt),
  );

  /// The menu: the sheet's actions, the colors in a submenu, no header
  /// (the place shows on hover).
  List<Widget> _menuItems(BuildContext context) => [
    MenuItemButton(
      // Takes the focus, so Esc closes the menu before the pointer moves.
      autofocus: true,
      leadingIcon: const Icon(_openIcon),
      onPressed: () => _apply(const OpenChoice()),
      child: const Text('Open'),
    ),
    MenuItemButton(
      leadingIcon: Icon(_pinIcon(pinned: widget.pinned)),
      onPressed: () => _apply(PinChoice(pinned: !widget.pinned)),
      child: Text(_pinLabel(pinned: widget.pinned)),
    ),
    SubmenuButton(
      leadingIcon: const Icon(Icons.palette_outlined),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 220,
            child: ColorCircles(
              selected: widget.color,
              onPicked: (color) {
                _menu.close();
                _apply(ColorChoice(color));
              },
            ),
          ),
        ),
      ],
      child: const Text('Color'),
    ),
    const Divider(),
    const MenuItemButton(
      child: Text('Move, rename, delete or backups: open the file'),
    ),
  ];
}

/// Lets the user pin [file] (on this device) or pick its color (on every
/// device), from the file's own page; then does it.
Future<void> editPinOrColor(
  BuildContext context,
  WidgetRef ref,
  ListedFile file,
) async {
  final choice = await _showFileSheet(
    context,
    pinned: ref.read(fileSettingsProvider.notifier).settingsOf(file.key).pinned,
    color: ref.read(fileActionsProvider).markOf(file).color,
  );
  if (choice != null && context.mounted) {
    await applyFileChoice(context, ref, file, choice);
  }
}

/// The sheet of a file's actions; with a [header] (on home), also Open
/// and where the rest is. The choice, or `null` if dismissed.
Future<FileChoice?> _showFileSheet(
  BuildContext context, {
  required bool pinned,
  required String? color,
  ({String title, String place})? header,
}) => showModalBottomSheet<FileChoice>(
  context: context,
  builder: (context) =>
      _FileSheet(header: header, pinned: pinned, color: color),
);

/// Closes with the choice on any tap.
class _FileSheet extends StatelessWidget {
  const _FileSheet({
    required this.header,
    required this.pinned,
    required this.color,
  });

  final ({String title, String place})? header;
  final bool pinned;
  final String? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void choose(FileChoice chosen) => Navigator.pop(context, chosen);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header case (:final title, :final place)) ...[
              ListTile(
                title: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(place),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(_openIcon),
                title: const Text('Open'),
                onTap: () => choose(const OpenChoice()),
              ),
            ],
            ListTile(
              leading: Icon(_pinIcon(pinned: pinned)),
              title: Text(_pinLabel(pinned: pinned)),
              onTap: () => choose(PinChoice(pinned: !pinned)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ColorCircles(
                selected: color,
                onPicked: (color) => choose(ColorChoice(color)),
              ),
            ),
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'To move, rename, delete or see backups, open the file.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _openIcon = Icons.description_outlined;

IconData _pinIcon({required bool pinned}) =>
    pinned ? Icons.push_pin : Icons.push_pin_outlined;

String _pinLabel({required bool pinned}) => pinned ? 'Unpin' : 'Pin';
