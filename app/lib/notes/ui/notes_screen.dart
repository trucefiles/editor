import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../conflicts/conflicts_controller.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../conflicts/ui/orphan_card.dart';
import '../../folders/folder_selection.dart';
import '../../folders/folders_controller.dart';
import '../../folders/note_folder.dart';
import '../../folders/ui/folder_filter_bar.dart';
import '../../folders/ui/folders_screen.dart';
import '../note.dart';
import '../note_files.dart';
import '../notes_controller.dart';
import 'new_note_dialog.dart';
import 'note_card.dart';
import 'note_editor_screen.dart';

/// Home: all notes as cards, filtered by folder.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onShow: () => ref.read(notesProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(foldersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            tooltip: 'Folders',
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const FoldersScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: switch (folders.value) {
        final list? when list.isNotEmpty => FloatingActionButton(
          tooltip: 'New note',
          onPressed: () => _create(list),
          child: const Icon(Icons.add),
        ),
        _ => null,
      },
      body: switch (folders) {
        AsyncData(value: final list) when list.isEmpty => const _NoFolders(),
        AsyncData(value: final list) => _NotesBody(list),
        AsyncError(error: FolderSettingsException(:final error)) => Center(
          child: Text(error.text),
        ),
        AsyncError() => const Center(child: Text('Something went wrong.')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _create(List<NoteFolder> folders) async {
    NoteFolder? byId(String? id) =>
        folders.where((folder) => folder.id == id).firstOrNull;
    final initial =
        byId(ref.read(selectedFolderIdProvider)) ??
        byId(ref.read(lastUsedFolderIdProvider)) ??
        folders.first;
    final input = await showNewNoteDialog(
      context,
      folders: folders,
      initial: initial,
    );
    if (input == null || !mounted) return;
    ref.read(lastUsedFolderIdProvider.notifier).choose(input.folder.id);
    final created = await ref
        .read(noteFilesProvider(input.folder))
        .create(input.title);
    if (!mounted) return;
    switch (created) {
      case Ok(value: final note):
        await ref.read(notesProvider.notifier).refresh();
        if (mounted) await openNote(context, note, autofocus: true);
      case Err(:final error):
        showSnack(context, error.text);
    }
  }
}

Future<void> openNote(
  BuildContext context,
  Note note, {
  bool autofocus = false,
}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => NoteEditorScreen(note, autofocus: autofocus),
  ),
);

class _NotesBody extends ConsumerWidget {
  const _NotesBody(this.folders);

  final List<NoteFolder> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedFolderIdProvider);
    final snapshot = ref.watch(notesProvider).value;
    final conflicts = ref.watch(conflictsProvider).value;
    bool shown(String folderId) => selectedId == null || folderId == selectedId;
    final notes = [
      for (final note in snapshot?.notes ?? const <Note>[])
        if (shown(note.folder.id)) note,
    ];
    final orphans = [
      for (final orphan in conflicts?.orphans ?? const <FolderConflict>[])
        if (shown(orphan.folder.id)) orphan,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FolderFilterBar(
          folders,
          conflictCount: (folder) => conflicts?.countIn(folder.id) ?? 0,
        ),
        for (final MapEntry(key: folder, value: error)
            in snapshot?.failedFolders.entries ??
                const <MapEntry<NoteFolder, StoreError>>[])
          ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(folder.name),
            subtitle: Text(error.text),
          ),
        Expanded(
          child: snapshot == null
              ? const Center(child: CircularProgressIndicator())
              : notes.isEmpty && orphans.isEmpty
              ? const Center(child: Text('No notes yet.'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisExtent: 200,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: orphans.length + notes.length,
                  itemBuilder: (context, index) {
                    if (index < orphans.length) {
                      final orphan = orphans[index];
                      return OrphanCard(
                        orphan,
                        onTap: () => openConflict(context, orphan),
                      );
                    }
                    final note = notes[index - orphans.length];
                    return NoteCard(
                      note,
                      hasConflict: conflicts?.forNote(note.key) != null,
                      onTap: () => openNote(context, note),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NoFolders extends ConsumerWidget {
  const _NoFolders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          const Text('Add a synced folder to see its notes.'),
          FilledButton.icon(
            onPressed: () => addFolder(context, ref),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Add folder'),
          ),
        ],
      ),
    );
  }
}
