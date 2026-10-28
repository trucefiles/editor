import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/snack.dart';
import '../../platform/platform_wiring.dart';
import '../../sync_tool/base_folder_services.dart';
import '../../sync_tool/sync_tools.dart';
import '../base_folder.dart';
import '../document_folder.dart';
import '../folder_actions.dart';
import '../folders_controller.dart';
import '../subfolders/subfolder_choice.dart';
import '../subfolders/ui/subfolder_choice_view.dart';
import 'folder_color_picker.dart';
import 'folder_error_text.dart';
import 'folder_notices_view.dart';

/// Whether the sync tool of [BaseFolder] keeps old versions the app can't
/// reach from it, for a hint to pick the synced folder itself.
final missesOldVersionsProvider = FutureProvider.autoDispose
    .family<bool, BaseFolder>(
      (ref, base) => ref
          .watch(syncToolsProvider)
          .of(base.toolId)
          .missesOldVersions(
            baseFolderMarkers(base.path, ref.watch(platformFactsProvider)),
          ),
    );

/// A folder's settings: its name, color and what it shows of its base
/// folder; and what its sync tool tells about it.
class FolderSettingsScreen extends ConsumerStatefulWidget {
  const FolderSettingsScreen(this.folder, {super.key});

  final DocumentFolder folder;

  @override
  ConsumerState<FolderSettingsScreen> createState() =>
      _FolderSettingsScreenState();
}

class _FolderSettingsScreenState extends ConsumerState<FolderSettingsScreen> {
  late final _name = TextEditingController(text: widget.folder.name);
  late Color _color = widget.folder.color;
  late final _parts = SubfolderChoice(
    names: ref.read(subfolderNamesProvider)(widget.folder.base.path),
    isToolFolder: ref.read(syncToolsProvider).isToolFolder,
    taken: [
      for (final other
          in ref.read(foldersProvider).value ?? const <DocumentFolder>[])
        if (other.base == widget.folder.base && other.id != widget.folder.id)
          other.selection,
    ],
    initial: widget.folder.selection,
  );
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _parts.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final selection = _parts.selection;
    if (name.isEmpty || selection == null) return;
    setState(() => _busy = true);
    final saved = await ref
        .read(folderActionsProvider)
        .change(
          widget.folder.copyWith(
            name: name,
            color: _color,
            selection: selection,
          ),
        );
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
    final base = widget.folder.base;
    final tool = ref.watch(syncToolsProvider).of(base.toolId);
    final hint = ref.watch(missesOldVersionsProvider(base)).value ?? false;
    final small = Theme.of(context).textTheme.bodySmall;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder'),
        actions: [
          ListenableBuilder(
            listenable: _parts,
            builder: (context, _) => TextButton(
              onPressed: _busy || _parts.selection == null ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(base.path, style: small),
          Text('Synced by: ${tool.rules.name}', style: small),
          FolderNoticesView(widget.folder),
          if (hint)
            Text(
              'Pick the ${tool.rules.name} folder itself to get more '
              'history.',
              style: small,
            ),
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
          const SizedBox(height: 16),
          SubfolderChoiceView(_parts),
        ],
      ),
    );
  }
}
