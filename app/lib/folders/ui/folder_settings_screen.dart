import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../common/snack.dart';
import '../../plugins/plugins_wiring.dart';
import '../folder_actions.dart';
import 'folder_color_picker.dart';
import 'folder_error_text.dart';
import 'folder_notices_view.dart';

/// A folder's settings: its name and color; where it is, its kind (the
/// plugin), and what its plugin tells about it.
class FolderSettingsScreen extends ConsumerStatefulWidget {
  const FolderSettingsScreen(this.folder, {super.key});

  final Folder folder;

  @override
  ConsumerState<FolderSettingsScreen> createState() =>
      _FolderSettingsScreenState();
}

class _FolderSettingsScreenState extends ConsumerState<FolderSettingsScreen> {
  late final _name = TextEditingController(text: widget.folder.name);
  late String _color = widget.folder.color;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = Folder.nameFrom(_name.text);
    if (name == null) return;
    setState(() => _busy = true);
    final saved = await ref
        .read(folderActionsProvider)
        .change(widget.folder.copyWith(name: name, color: _color));
    if (!mounted) return;
    setState(() => _busy = false);
    switch (saved) {
      case Ok():
        Navigator.pop(context);
      case Err(:final error):
        showSnack(context, error.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final folder = widget.folder;
    final plugin = ref.watch(folderPluginsProvider).of(folder.id.plugin);
    final small = Theme.of(context).textTheme.bodySmall;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _name,
            builder: (context, typed, _) => TextButton(
              onPressed: _busy || Folder.nameFrom(typed.text) == null
                  ? null
                  : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(folder.location, style: small),
          Text('${plugin.name}: ${plugin.helpLine}', style: small),
          FolderNoticesView(folder),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 16),
          FolderColorPicker(
            selected: _color,
            onPicked: (color) => setState(() => _color = color),
          ),
        ],
      ),
    );
  }
}
