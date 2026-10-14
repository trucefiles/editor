import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/empty_state.dart';
import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../conflicts/backup_pruning.dart';
import '../../conflicts/folder_conflicts.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../conflicts/ui/orphan_card.dart';
import '../../folders/folder_selection.dart';
import '../../folders/folders_controller.dart';
import '../../folders/note_folder.dart';
import '../../folders/ui/folder_filter_bar.dart';
import '../../folders/ui/folders_screen.dart';
import '../../folders/ui/settings_error_text.dart';
import '../../scan/folder_scans_controller.dart';
import '../../search/ui/search_screen.dart';
import '../../tray/ui/close_to_tray_menu.dart';
import '../note.dart';
import '../note_actions.dart';
import '../note_views_controller.dart';
import 'new_note_dialog.dart';
import 'note_card.dart';
import 'note_grid.dart';
import 'note_mark_sheet.dart';
import 'note_sections.dart';

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
      onShow: () => ref.read(folderScansProvider.notifier).refresh(),
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
    // Loaded up front, so a note opens in its remembered view.
    ref
      ..watch(noteViewsProvider)
      ..watch(backupPruningProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Folders',
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const FoldersScreen()),
            ),
          ),
          const CloseToTrayMenu(),
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
    final actions = ref.read(noteActionsProvider);
    final input = await showNewNoteDialog(
      context,
      folders: folders,
      initial: actions.defaultFolder(folders),
      subfoldersOf: (folder) =>
          ref.read(folderScansProvider).value?.subfoldersOf(folder.id) ??
          const [],
    );
    if (input == null) return;
    final created = await actions.create(
      input.title,
      input.folder,
      subfolder: input.subfolder,
    );
    if (!mounted) return;
    switch (created) {
      case Ok(value: final note):
        await openNote(context, note, autofocus: true);
      case Err(:final error):
        showSnack(context, error.text);
    }
  }
}

class _NotesBody extends ConsumerWidget {
  const _NotesBody(this.folders);

  final List<NoteFolder> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedFolderIdProvider);
    final scans = ref.watch(folderScansProvider).value;
    final conflicts = scans?.conflicts;
    NoteMark markOf(Note note) => scans?.markOf(note.key) ?? NoteMark.none;
    bool shown(String folderId) => selectedId == null || folderId == selectedId;
    final notes = [
      for (final note in scans?.notes ?? const <Note>[])
        if (shown(note.folder.id)) note,
    ];
    bool pinned(Note note) => markOf(note).pinned;
    Widget card(Note note) => NoteCard(
      note,
      mark: markOf(note),
      hasConflict: conflicts?.forNote(note.key) != null,
      onTap: () => openNote(context, note),
      onMark: () => editNoteMark(context, ref, note),
    );
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
            in scans?.failedFolders.entries ??
                const <MapEntry<NoteFolder, StoreError>>[])
          ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(folder.name),
            subtitle: Text(error.text),
          ),
        Expanded(
          child: scans == null
              ? const Center(child: CircularProgressIndicator())
              : notes.isEmpty && orphans.isEmpty
              ? const EmptyState(
                  icon: Icons.sticky_note_2_outlined,
                  text: 'No notes yet.',
                )
              : NoteSections(
                  leading: [
                    for (final orphan in orphans)
                      OrphanCard(
                        orphan,
                        onTap: () => openConflict(context, orphan),
                      ),
                  ],
                  pinned: [
                    for (final note in notes)
                      if (pinned(note)) card(note),
                  ],
                  others: [
                    for (final note in notes)
                      if (!pinned(note)) card(note),
                  ],
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
    return EmptyState(
      icon: Icons.folder_open_outlined,
      text: 'Add a synced folder to see its notes.',
      action: FilledButton.icon(
        onPressed: () => addFolder(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Add folder'),
      ),
    );
  }
}
