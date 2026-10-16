import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../backups/backup_pruning.dart';
import '../../common/empty_state.dart';
import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../conflicts/folder_conflicts.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../conflicts/ui/conflicts_screen.dart';
import '../../conflicts/ui/orphan_card.dart';
import '../../folders/folder_selection.dart';
import '../../folders/folders_controller.dart';
import '../../folders/note_folder.dart';
import '../../folders/ui/folder_filter_bar.dart';
import '../../folders/ui/folder_problems.dart';
import '../../folders/ui/folders_screen.dart';
import '../../folders/ui/settings_error_text.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../scan/auto_rescan.dart';
import '../../scan/folder_scans_controller.dart';
import '../../search/ui/search_screen.dart';
import '../note.dart';
import '../note_actions.dart';
import '../note_settings_controller.dart';
import '../note_settings_pruning.dart';
import 'home_menu.dart';
import 'new_note_dialog.dart';
import 'note_card.dart';
import 'note_grid.dart';
import 'note_sections.dart';
import 'pin_or_color_sheet.dart';

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
    // On desktop, also when the window gets the focus back.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() => ref.read(folderScansProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(foldersProvider);
    // Loaded up front, so a note opens in its remembered view.
    ref
      ..watch(noteSettingsProvider)
      ..watch(backupPruningProvider)
      ..watch(noteSettingsPruningProvider)
      ..watch(autoRescanProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          const _ConflictsButton(),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Manage folders',
            icon: const Icon(Icons.folder_outlined),
            onPressed: () => openFoldersScreen(context, ref),
          ),
          const HomeMenu(),
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

  Future<void> _create(List<NoteFolder> all) async {
    final actions = ref.read(noteActionsProvider);
    // Change events don't tell about new empty subfolders; a rescan finds
    // them, so the dialog offers them.
    await _refresh();
    if (!mounted) return;
    final folders = actions.reachableOf(all);
    if (folders.isEmpty) {
      return showSnack(context, 'No folder can be reached right now.');
    }
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
    ref.watch(noteSettingsProvider);
    final settings = ref.read(noteSettingsProvider.notifier);
    bool pinned(Note note) => settings.settingsOf(note.key).pinned;
    Widget card(Note note) => NoteCard(
      note,
      mark: markOf(note),
      pinned: pinned(note),
      hasConflict: conflicts?.forNote(note.key) != null,
      onTap: () => openNote(context, note),
      onMark: () => editPinOrColor(context, ref, note),
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
        if (scans != null) FolderProblems(scans, folders: folders),
        Expanded(
          child: scans == null
              ? const Center(child: CircularProgressIndicator())
              : notes.isEmpty && orphans.isEmpty
              ? const EmptyState(
                  icon: Icons.sticky_note_2_outlined,
                  text: 'No notes yet.',
                )
              : PullToRefresh(
                  onRefresh: ref.read(folderScansProvider.notifier).refresh,
                  child: NoteSections(
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
        ),
      ],
    );
  }
}

/// Opens the list of all conflicts; shown only while there are some, with
/// their count.
class _ConflictsButton extends ConsumerWidget {
  const _ConflictsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(folderScansProvider).value?.conflicts.all.length ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Conflicts',
      icon: Badge.count(count: count, child: const Icon(Icons.call_split)),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const ConflictsScreen()),
      ),
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
