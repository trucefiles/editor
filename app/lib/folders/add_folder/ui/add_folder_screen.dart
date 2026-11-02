import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../../common/snack.dart';
import '../../../plugins/plugins_wiring.dart';
import '../../../plugins/wired_plugin.dart';
import '../../folder_colors.dart';
import '../../folders_controller.dart';
import '../../ui/folder_color_picker.dart';
import '../../ui/folder_error_text.dart';
import '../add_folder_flow.dart';

/// Adds folders, step by step (see [AddFolderFlow]).
class AddFolderScreen extends ConsumerStatefulWidget {
  const AddFolderScreen({super.key});

  @override
  ConsumerState<AddFolderScreen> createState() => _AddFolderScreenState();
}

class _AddFolderScreenState extends ConsumerState<AddFolderScreen> {
  late final AddFolderFlow _flow = AddFolderFlow(
    colors: folderColors.keys.toList(),
    usedColors: [
      for (final folder in ref.read(foldersProvider).value ?? const <Folder>[])
        folder.color,
    ],
    add: ref.read(foldersProvider.notifier).add,
  );
  bool _busy = false;

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: _flow.changes,
    builder: (context, _) => PopScope(
      canPop: _flow.step is ChoosingPlugin,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _flow.back();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Add folder')),
        body: SafeArea(
          child: switch (_flow.step) {
            ChoosingPlugin() => _PluginStep(
              ref.watch(wiredPluginsProvider),
              onChosen: _openAddPage,
            ),
            final NamingFolder naming => _NameStep(
              naming,
              flow: _flow,
              onDone: _busy ? null : _done,
            ),
          },
        ),
      ),
    ),
  );

  Future<void> _openAddPage(WiredPlugin wired) async {
    final candidates = await wired.addPage(context);
    if (candidates != null && mounted) _flow.took(wired.plugin, candidates);
  }

  Future<void> _done() async {
    if (_flow.step case NamingFolder(isLast: false)) return _flow.next();
    setState(() => _busy = true);
    final added = await _flow.finish();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (added) {
      case Ok():
        Navigator.pop(context);
      case Err(:final error):
        showSnack(context, error.text);
    }
  }
}

/// Pick how the folder is synced: the plugins, each with its help line.
class _PluginStep extends StatelessWidget {
  const _PluginStep(this.plugins, {required this.onChosen});

  final List<WiredPlugin> plugins;
  final void Function(WiredPlugin wired) onChosen;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('How is the folder synced?'),
      const SizedBox(height: 8),
      for (final wired in plugins)
        ListTile(
          title: Text(wired.plugin.name),
          subtitle: Text(wired.plugin.helpLine),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onChosen(wired),
        ),
    ],
  );
}

/// Name and color of one new folder.
class _NameStep extends StatelessWidget {
  const _NameStep(this.naming, {required this.flow, required this.onDone});

  final NamingFolder naming;
  final AddFolderFlow flow;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (naming.count > 1)
              Text('Folder ${naming.index + 1} of ${naming.count}'),
            Text(naming.location, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextFormField(
              // A new field for each folder, so it starts with its name.
              key: ValueKey(naming.index),
              initialValue: naming.name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: flow.rename,
            ),
            const SizedBox(height: 16),
            FolderColorPicker(selected: naming.color, onPicked: flow.recolor),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: naming.hasName ? onDone : null,
            child: Text(naming.isLast ? 'Add' : 'Next'),
          ),
        ),
      ),
    ],
  );
}
