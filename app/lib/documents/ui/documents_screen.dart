import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems;

import '../../backups/backup_pruning.dart';
import '../../common/empty_state.dart';
import '../../common/filled_scroll_view.dart';
import '../../common/snack.dart';
import '../../conflicts/folder_conflicts.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../conflicts/ui/conflicts_screen.dart';
import '../../conflicts/ui/orphan_card.dart';
import '../../document_page/ui/document_screen.dart';
import '../../folders/document_folder.dart';
import '../../folders/folder_selection.dart';
import '../../folders/folders_controller.dart';
import '../../folders/ui/folder_filter_bar.dart';
import '../../folders/ui/folder_problems.dart';
import '../../folders/ui/folders_screen.dart';
import '../../folders/ui/settings_error_text.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../scan/auto_rescan.dart';
import '../../scan/folder_scans_controller.dart';
import '../../search/ui/search_screen.dart';
import '../document.dart';
import '../document_actions.dart';
import '../document_settings_controller.dart';
import '../document_settings_pruning.dart';
import '../new_document_place/new_document_place_controller.dart';
import 'document_card.dart';
import 'document_grid.dart';
import 'document_sections.dart';
import 'home_menu.dart';
import 'pin_or_color_sheet.dart';

/// Home: all documents as cards, filtered by folder.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  late final AppLifecycleListener _lifecycle;
  final _pull = GlobalKey<PullToRefreshState>();

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
    // Loaded up front, so a document opens in its remembered view and a new
    // one goes to the place set.
    ref
      ..watch(documentSettingsProvider)
      ..watch(newNotePlaceProvider)
      ..watch(backupPruningProvider)
      ..watch(documentSettingsPruningProvider)
      ..watch(autoRescanProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            // Only while there are documents to show, with the pull's indicator.
            onPressed: switch (folders) {
              AsyncData(value: final list) when list.isNotEmpty =>
                () => _pull.currentState!.refresh(),
              _ => null,
            },
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
          tooltip: 'New document',
          onPressed: () => _create(list),
          child: const Icon(Icons.edit),
        ),
        _ => null,
      },
      body: switch (folders) {
        AsyncData(value: final list) when list.isEmpty => const _NoFolders(),
        AsyncData(value: final list) => _DocumentsBody(list, pull: _pull),
        AsyncError(error: FolderSettingsException(:final error)) => Center(
          child: Text(error.text),
        ),
        AsyncError() => const Center(
          child: Text("Your documents couldn't be loaded."),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Opens a new document in the place for new documents, if any folder can take
  /// it.
  Future<void> _create(List<DocumentFolder> all) async {
    final actions = ref.read(documentActionsProvider);
    final folders = actions.reachableOf(all);
    if (folders.isEmpty) {
      return showSnack(context, 'No folder can be reached right now.');
    }
    final place = actions.newNotePlace(folders);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => DocumentScreen.fresh(place)),
    );
  }
}

class _DocumentsBody extends ConsumerWidget {
  const _DocumentsBody(this.folders, {required this.pull});

  final List<DocumentFolder> folders;

  /// The key of the documents' [PullToRefresh].
  final GlobalKey<PullToRefreshState> pull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedFolderIdProvider);
    final scans = ref.watch(folderScansProvider).value;
    final conflicts = scans?.conflicts;
    DocumentMark markOf(Document document) =>
        scans?.markOf(document.key) ?? DocumentMark.none;
    bool shown(String folderId) => selectedId == null || folderId == selectedId;
    final documents = [
      for (final document in scans?.documents ?? const <Document>[])
        if (shown(document.folder.id)) document,
    ];
    ref.watch(documentSettingsProvider);
    final settings = ref.read(documentSettingsProvider.notifier);
    bool pinned(Document document) => settings.settingsOf(document.key).pinned;
    Widget card(Document document) => DocumentCard(
      document,
      mark: markOf(document),
      pinned: pinned(document),
      hasConflict: conflicts?.forNote(document.key) != null,
      hideDone:
          settings.settingsOf(document.key).checkedItems !=
          CheckedItems.inPlace,
      onTap: () => openNote(context, document),
      onMark: () => editPinOrColor(context, ref, document),
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
          child: PullToRefresh(
            key: pull,
            onRefresh: ref.read(folderScansProvider.notifier).refresh,
            child: scans == null
                ? const FilledScrollView(child: CircularProgressIndicator())
                : documents.isEmpty && orphans.isEmpty
                ? const FilledScrollView(
                    child: EmptyState(
                      icon: Icons.sticky_note_2_outlined,
                      text: 'No documents yet.',
                    ),
                  )
                : DocumentSections(
                    leading: [
                      for (final orphan in orphans)
                        OrphanCard(
                          orphan,
                          onTap: () => openConflict(context, orphan),
                        ),
                    ],
                    pinned: [
                      for (final document in documents)
                        if (pinned(document)) card(document),
                    ],
                    others: [
                      for (final document in documents)
                        if (!pinned(document)) card(document),
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
      text: 'Add a synced folder to see its documents.',
      action: FilledButton.icon(
        onPressed: () => addFolder(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Add folder'),
      ),
    );
  }
}
