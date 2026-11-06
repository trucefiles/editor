import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../folders/ui/folder_badge.dart';

/// Asks for a folder of [folders] and, if [subfoldersOf] the folder offers
/// any, a folder inside it, starting at [initial]; titled [title], with
/// [action] on the confirming button. The chosen place, or `null` if
/// cancelled.
Future<FilePlace?> showFilePlaceDialog(
  BuildContext context, {
  required String title,
  required String action,
  required List<Folder> folders,
  required FilePlace initial,
  required List<RelPath> Function(Folder folder) subfoldersOf,
}) async => (await showDialog<_Choice>(
  context: context,
  builder: (_) =>
      _FilePlaceDialog(title, action, folders, initial, subfoldersOf, null),
))?.place;

/// Like [showFilePlaceDialog], also asking for a file name without
/// its extension, starting at [name]; [nameHint] says what an empty name
/// gives. A folder inside may also be typed, a new one too, if [canHold]
/// says files of the folder can go there. The chosen place and name;
/// `null` if cancelled.
Future<PickedPlace?> showFileNameDialog(
  BuildContext context, {
  String title = 'Location and name',
  String action = 'OK',
  required List<Folder> folders,
  required FilePlace initial,
  required String name,
  required String nameHint,
  required List<RelPath> Function(Folder folder) subfoldersOf,
  required bool Function(Folder folder, RelPath subfolder) canHold,
}) async => switch (await showDialog<_Choice>(
  context: context,
  builder: (_) => _FilePlaceDialog(
    title,
    action,
    folders,
    initial,
    subfoldersOf,
    name,
    nameHint: nameHint,
    canHold: canHold,
  ),
)) {
  (:final place, name: final name?, :final newSubfolder) => (
    place: place,
    name: name,
    newSubfolder: newSubfolder,
  ),
  _ => null,
};

typedef _Choice = ({FilePlace place, String? name, bool newSubfolder});

class _FilePlaceDialog extends StatefulWidget {
  const _FilePlaceDialog(
    this.title,
    this.action,
    this.folders,
    this.initial,
    this.subfoldersOf,
    this.name, {
    this.nameHint,
    this.canHold,
  });

  final String title;
  final String action;
  final List<Folder> folders;
  final FilePlace initial;
  final List<RelPath> Function(Folder folder) subfoldersOf;

  /// The file name to start at; `null` asks for none.
  final String? name;

  /// What an empty [name] gives.
  final String? nameHint;

  /// Whether files of a folder can go into a typed subfolder; `null`:
  /// only the subfolders offered can be picked.
  final bool Function(Folder folder, RelPath subfolder)? canHold;

  @override
  State<_FilePlaceDialog> createState() => _FilePlaceDialogState();
}

class _FilePlaceDialogState extends State<_FilePlaceDialog> {
  late Folder _folder = widget.folders.contains(widget.initial.folder)
      ? widget.initial.folder
      : widget.folders.first;
  late RelPath? _subfolder = _offers(widget.initial.subfolder)
      ? widget.initial.subfolder
      : null;

  late final _name = TextEditingController(text: widget.name);

  /// The subfolder as typed, while it can be typed.
  late final _typed = TextEditingController(text: _subfolder?.value)
    ..addListener(_onTyped);
  String? _typedError;

  /// The error goes as the user changes the text.
  void _onTyped() {
    if (_typedError != null) setState(() => _typedError = null);
  }

  List<RelPath> get _subfolders => widget.subfoldersOf(_folder);

  bool _offers(RelPath? subfolder) =>
      subfolder == null || _subfolders.contains(subfolder);

  @override
  void dispose() {
    _name.dispose();
    _typed.dispose();
    super.dispose();
  }

  void _confirm() {
    if (widget.canHold != null) {
      final (subfolder, error) = _typedSubfolder();
      if (error != null) return setState(() => _typedError = error);
      _subfolder = subfolder;
    }
    Navigator.pop<_Choice>(context, (
      place: (folder: _folder, subfolder: _subfolder),
      name: widget.name == null ? null : _name.text,
      newSubfolder: switch (_subfolder) {
        final subfolder? => !_subfolders.contains(subfolder),
        null => false,
      },
    ));
  }

  /// The typed subfolder, or why files can't go there. A quick check
  /// for the user; the folder's files refuse a place outside it anyway.
  (RelPath?, String?) _typedSubfolder() {
    final text = _typed.text.trim().replaceFirst(RegExp(r'/+$'), '');
    if (text.isEmpty) return (null, null);
    final subfolder = RelPath.parse(text);
    return subfolder != null && widget.canHold!(_folder, subfolder)
        ? (subfolder, null)
        : (null, "Files can't go in there.");
  }

  static const _topLevel = '(top level)';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Folder>(
            initialValue: _folder,
            decoration: const InputDecoration(labelText: 'Folder'),
            items: [
              for (final folder in widget.folders)
                DropdownMenuItem(value: folder, child: FolderBadge(folder)),
            ],
            onChanged: (folder) => setState(() {
              _folder = folder ?? _folder;
              _subfolder = null;
              _typed.text = _subfolder?.value ?? '';
              _typedError = null;
            }),
          ),
          if (widget.canHold != null) ...[
            const SizedBox(height: 16),
            _TypedSubfolder(
              // A new key per folder resets the field to the folder's top.
              key: ValueKey(_folder.id),
              controller: _typed,
              subfolders: _subfolders,
              topLevel: _topLevel,
              errorText: _typedError,
            ),
          ] else if (_subfolders case final subfolders
              when subfolders.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<RelPath?>(
              // A new key per folder resets the field to the folder's top.
              key: ValueKey(_folder.id),
              initialValue: _subfolder,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Inside the folder'),
              items: [
                const DropdownMenuItem(child: Text(_topLevel)),
                for (final subfolder in subfolders)
                  DropdownMenuItem(
                    value: subfolder,
                    child: Text(
                      subfolder.value,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (subfolder) => setState(() => _subfolder = subfolder),
            ),
          ],
          if (widget.name != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: widget.nameHint,
                // An empty name shows its hint, not only once focused.
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: Text(widget.action)),
      ],
    );
  }
}

/// A folder inside to pick from those offered, or to type, a new one too.
/// Empty is the top level: it shows [topLevel] as a hint, never as text,
/// so nothing typed after it reads as a folder inside it.
class _TypedSubfolder extends StatelessWidget {
  const _TypedSubfolder({
    required this.controller,
    required this.subfolders,
    required this.topLevel,
    required this.errorText,
    super.key,
  });

  final TextEditingController controller;
  final List<RelPath> subfolders;
  final String topLevel;
  final String? errorText;

  @override
  Widget build(BuildContext context) => DropdownMenu<String>(
    controller: controller,
    expandedInsets: EdgeInsets.zero,
    requestFocusOnTap: true,
    // Looks like the dialog's other fields, which follow the app's theme.
    inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
      border: const UnderlineInputBorder(),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      helperMaxLines: 2,
      errorMaxLines: 3,
    ),
    // A plain arrow at the field's end, where the other fields have theirs;
    // a tap anywhere on the field opens the list.
    decorationBuilder: (context, menu) => InputDecoration(
      label: const Text('Inside the folder'),
      hintText: topLevel,
      helperText: 'Pick one, or type a new one',
      errorText: errorText,
      suffixIcon: Icon(
        menu.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
      ),
      suffixIconConstraints: const BoxConstraints(),
    ),
    dropdownMenuEntries: [
      // Picking it empties the field, which then shows the hint.
      DropdownMenuEntry(value: '', label: '', labelWidget: Text(topLevel)),
      for (final subfolder in subfolders)
        DropdownMenuEntry(value: subfolder.value, label: subfolder.value),
    ],
  );
}
