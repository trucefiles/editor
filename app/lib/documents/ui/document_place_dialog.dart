import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../folders/document_folder.dart';
import '../../folders/ui/folder_badge.dart';
import '../document_place.dart';

/// Asks for a folder of [folders] and, if [subfoldersOf] the folder offers
/// any, one of its subfolders, starting at [initial]; titled [title], with
/// [action] on the confirming button. The chosen place, or `null` if
/// cancelled.
Future<DocumentPlace?> showDocumentPlaceDialog(
  BuildContext context, {
  required String title,
  required String action,
  required List<DocumentFolder> folders,
  required DocumentPlace initial,
  required List<RelPath> Function(DocumentFolder folder) subfoldersOf,
}) async => (await showDialog<_Choice>(
  context: context,
  builder: (_) =>
      _DocumentPlaceDialog(title, action, folders, initial, subfoldersOf, null),
))?.place;

/// Like [showDocumentPlaceDialog], also asking for a document's file name without
/// its extension, starting at [name]. A subfolder may also be typed, a new
/// one too, if [canHold] says documents of the folder can go there. The
/// chosen place and name; `null` if cancelled.
Future<PickedPlace?> showDocumentFileDialog(
  BuildContext context, {
  required List<DocumentFolder> folders,
  required DocumentPlace initial,
  required String name,
  required List<RelPath> Function(DocumentFolder folder) subfoldersOf,
  required bool Function(DocumentFolder folder, RelPath subfolder) canHold,
}) async => switch (await showDialog<_Choice>(
  context: context,
  builder: (_) => _DocumentPlaceDialog(
    'Place and name',
    'OK',
    folders,
    initial,
    subfoldersOf,
    name,
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

/// A place and name the user picked, the name as typed; [newSubfolder]:
/// the place's subfolder is a new one, made with the document's first
/// write there.
typedef PickedPlace = ({DocumentPlace place, String name, bool newSubfolder});

typedef _Choice = ({DocumentPlace place, String? name, bool newSubfolder});

class _DocumentPlaceDialog extends StatefulWidget {
  const _DocumentPlaceDialog(
    this.title,
    this.action,
    this.folders,
    this.initial,
    this.subfoldersOf,
    this.name, {
    this.canHold,
  });

  final String title;
  final String action;
  final List<DocumentFolder> folders;
  final DocumentPlace initial;
  final List<RelPath> Function(DocumentFolder folder) subfoldersOf;

  /// The file name to start at; `null` asks for none.
  final String? name;

  /// Whether documents of a folder can go into a typed subfolder; `null`:
  /// only the subfolders offered can be picked.
  final bool Function(DocumentFolder folder, RelPath subfolder)? canHold;

  @override
  State<_DocumentPlaceDialog> createState() => _DocumentPlaceDialogState();
}

class _DocumentPlaceDialogState extends State<_DocumentPlaceDialog> {
  late DocumentFolder _folder = widget.folders.contains(widget.initial.folder)
      ? widget.initial.folder
      : widget.folders.first;
  late RelPath? _subfolder = _offers(widget.initial.subfolder)
      ? widget.initial.subfolder
      : _top;

  late final _name = TextEditingController(text: widget.name);

  /// The subfolder as typed, while it can be typed.
  late final _typed = TextEditingController(text: _subfolder?.value)
    ..addListener(_onTyped);
  String? _typedError;

  /// Whether the top level was picked from the list (its label shows):
  /// a subfolder named like it is still a subfolder.
  var _topLevelPicked = false;

  /// The error goes as the user changes the text.
  void _onTyped() {
    if (_typed.text != _topLevel) _topLevelPicked = false;
    if (_typedError != null) setState(() => _typedError = null);
  }

  List<RelPath> get _subfolders => widget.subfoldersOf(_folder);

  /// Whether the base folder's top level can be picked in [_folder].
  bool get _offersTopLevel => _folder.selection is WholeFolder;

  bool _offers(RelPath? subfolder) =>
      subfolder == null ? _offersTopLevel : _subfolders.contains(subfolder);

  /// Where [_folder] starts: its top as the last scan found it.
  RelPath? get _top => _offersTopLevel
      ? null
      : _subfolders.firstOrNull ?? topOf(_folder).subfolder;

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

  /// The typed subfolder, or why documents can't go there. A quick check
  /// for the user; the folder's files refuse a place outside it anyway.
  (RelPath?, String?) _typedSubfolder() {
    final text = _typed.text.trim().replaceFirst(RegExp(r'/+$'), '');
    if (text.isEmpty || _topLevelPicked) {
      return _offersTopLevel
          ? (null, null)
          : (null, 'Pick or type a subfolder.');
    }
    final subfolder = RelPath.parse(text);
    return subfolder != null && widget.canHold!(_folder, subfolder)
        ? (subfolder, null)
        : (null, "Documents of this folder can't go there.");
  }

  static const _topLevel = 'Top level';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<DocumentFolder>(
            initialValue: _folder,
            decoration: const InputDecoration(labelText: 'Folder'),
            items: [
              for (final folder in widget.folders)
                DropdownMenuItem(value: folder, child: FolderBadge(folder)),
            ],
            onChanged: (folder) => setState(() {
              _folder = folder ?? _folder;
              _subfolder = _top;
              _typed.text = _subfolder?.value ?? '';
              _typedError = null;
              _topLevelPicked = false;
            }),
          ),
          if (widget.canHold != null) ...[
            const SizedBox(height: 16),
            _TypedSubfolder(
              // A new key per folder resets the field to the folder's top.
              key: ValueKey(_folder.id),
              controller: _typed,
              offersTopLevel: _offersTopLevel,
              subfolders: _subfolders,
              topLevel: _topLevel,
              errorText: _typedError,
              onPicked: (value) => _topLevelPicked = value.isEmpty,
            ),
          ] else if (_subfolders case final subfolders
              when subfolders.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<RelPath?>(
              // A new key per folder resets the field to the folder's top.
              key: ValueKey(_folder.id),
              initialValue: _subfolder,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Subfolder'),
              items: [
                if (_offersTopLevel)
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
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'From the first line',
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

/// A subfolder to pick from those offered, or to type, a new one too.
class _TypedSubfolder extends StatelessWidget {
  const _TypedSubfolder({
    required this.controller,
    required this.offersTopLevel,
    required this.subfolders,
    required this.topLevel,
    required this.errorText,
    required this.onPicked,
    super.key,
  });

  final TextEditingController controller;
  final bool offersTopLevel;
  final List<RelPath> subfolders;
  final String topLevel;
  final String? errorText;

  /// Called with the value of an entry picked: the subfolder's path, or
  /// empty for the top level.
  final void Function(String value) onPicked;

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
      label: const Text('Subfolder'),
      hintText: offersTopLevel ? topLevel : null,
      helperText: 'Pick one, or type a new one',
      errorText: errorText,
      suffixIcon: Icon(
        menu.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
      ),
      suffixIconConstraints: const BoxConstraints(),
    ),
    onSelected: (value) => onPicked(value ?? ''),
    dropdownMenuEntries: [
      if (offersTopLevel) DropdownMenuEntry(value: '', label: topLevel),
      for (final subfolder in subfolders)
        DropdownMenuEntry(value: subfolder.value, label: subfolder.value),
    ],
  );
}
