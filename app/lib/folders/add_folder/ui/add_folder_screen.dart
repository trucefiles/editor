import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../../common/snack.dart';
import '../../../platform/folder_picker.dart';
import '../../folders_controller.dart';
import '../../subfolders/ui/subfolder_choice_view.dart';
import '../../ui/folder_color_picker.dart';
import '../../ui/folder_error_text.dart';
import '../add_folder_flow.dart';
import '../add_folder_wiring.dart';

/// Adds a folder, step by step (see [AddFolderStep]).
class AddFolderScreen extends ConsumerStatefulWidget {
  const AddFolderScreen({super.key});

  @override
  ConsumerState<AddFolderScreen> createState() => _AddFolderScreenState();
}

class _AddFolderScreenState extends ConsumerState<AddFolderScreen> {
  late final AddFolderFlow _flow = AddFolderFlow(
    ref.read(addFolderWorkProvider),
    ref.read(foldersProvider).value ?? const [],
  );
  bool _busy = false;

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _flow,
    builder: (context, _) => PopScope(
      canPop: _flow.step == AddFolderStep.base,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _flow.back();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Add folder')),
        body: SafeArea(
          child: switch (_flow.step) {
            AddFolderStep.base => _BaseStep(_flow, onPick: _pickBase),
            AddFolderStep.tool => _ToolStep(_flow),
            AddFolderStep.parts => _PartsStep(_flow),
            AddFolderStep.name => _NameStep(
              _flow,
              onAdd: _busy ? null : _finish,
            ),
          },
        ),
      ),
    ),
  );

  Future<void> _pickBase() async {
    switch (await ref.read(folderPickerProvider).pick()) {
      case Ok(value: final path?):
        await _flow.pickBase(path);
      case Ok():
        break;
      case Err(error: PickError.unsupportedLocation):
        if (mounted) {
          showSnack(
            context,
            "This folder can't be opened by the app. Please pick one on "
            "the device's main storage.",
          );
        }
    }
  }

  Future<void> _finish() async {
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

/// Pick a folder on the device, or one added before.
class _BaseStep extends StatelessWidget {
  const _BaseStep(this.flow, {required this.onPick});

  final AddFolderFlow flow;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('Which folder holds your documents?'),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.folder_open_outlined),
        label: const Text('Pick a folder'),
      ),
      if (flow.bases.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text('Or show more of a folder added before:'),
        for (final base in flow.bases)
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(base.path),
            onTap: () => flow.pickBase(base.path),
          ),
      ],
    ],
  );
}

/// Say which sync tool syncs the folder, when the app can't tell.
class _ToolStep extends StatelessWidget {
  const _ToolStep(this.flow);

  final AddFolderFlow flow;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('How is ${flow.basePath} synced?'),
      const SizedBox(height: 8),
      for (final tool in flow.tools)
        ListTile(
          title: Text(tool.rules.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => flow.chooseTool(tool),
        ),
      const SizedBox(height: 8),
      Text(
        'Pick Plain folder if no sync app syncs it, or one the app '
        "doesn't know.",
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

/// The whole folder, or some subfolders.
class _PartsStep extends StatelessWidget {
  const _PartsStep(this.flow);

  final AddFolderFlow flow;

  @override
  Widget build(BuildContext context) => _StepPage(
    action: ListenableBuilder(
      listenable: flow.parts,
      builder: (context, _) => FilledButton(
        onPressed: flow.parts.selection == null ? null : flow.toName,
        child: const Text('Next'),
      ),
    ),
    children: [
      Text('What should the app show of ${flow.basePath}?'),
      const SizedBox(height: 8),
      SubfolderChoiceView(flow.parts),
    ],
  );
}

/// Name and color.
class _NameStep extends StatelessWidget {
  const _NameStep(this.flow, {required this.onAdd});

  final AddFolderFlow flow;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => _StepPage(
    action: FilledButton(onPressed: onAdd, child: const Text('Add')),
    children: [
      TextFormField(
        initialValue: flow.name,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onChanged: flow.rename,
      ),
      const SizedBox(height: 16),
      FolderColorPicker(selected: flow.color, onPicked: flow.recolor),
    ],
  );
}

/// A step's content, scrolling, with its [action] below.
class _StepPage extends StatelessWidget {
  const _StepPage({required this.children, required this.action});

  final List<Widget> children;
  final Widget action;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Align(alignment: AlignmentDirectional.centerEnd, child: action),
      ),
    ],
  );
}
