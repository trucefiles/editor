import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../backups/backup_pruning.dart';
import '../../common/empty_state.dart';
import '../../common/filled_scroll_view.dart';
import '../../common/snack.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../conflicts/ui/conflicts_screen.dart';
import '../../conflicts/ui/orphan_card.dart';
import '../../file_page/ui/file_screen.dart';
import '../../file_types/file_types.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../folder_state/folder_state_wiring.dart';
import '../../folders/folders_controller.dart';
import '../../folders/ui/folder_problems.dart';
import '../../folders/ui/folders_screen.dart';
import '../../folders/ui/settings_error_text.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../search/ui/search_screen.dart';
import '../../settings/device_settings_controller.dart';
import '../file_actions.dart';
import '../file_settings_controller.dart';
import '../file_settings_pruning.dart';
import '../home_filter_provider.dart';
import '../home_view.dart';
import '../new_file/pick_new_file.dart';
import 'all_files_view.dart';
import 'file_sections.dart';
import 'home_filter_bar.dart';
import 'home_menu.dart';
import 'home_view_button.dart';
import 'listed_file_card.dart';

/// Home: the recent files as cards, pinned ones first, or all files,
/// filtered by folder and type.
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
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

  Future<void> _refresh() =>
      ref.read(folderContentsProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(folderListStateProvider);
    // Loaded up front, so a file opens in its remembered view.
    ref
      ..watch(fileSettingsProvider)
      ..watch(backupPruningProvider)
      ..watch(fileSettingsPruningProvider)
      ..watch(followingChangesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            // Only while there are files to show, with the pull's indicator.
            onPressed: switch (folders) {
              FoldersLoaded(folders: final list) when list.isNotEmpty =>
                () => _pull.currentState!.refresh(),
              _ => null,
            },
          ),
          const HomeViewButton(),
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
      floatingActionButton: switch (folders) {
        FoldersLoaded(folders: final list) when list.isNotEmpty =>
          FloatingActionButton(
            tooltip: 'New file',
            onPressed: () => _create(list),
            child: const Icon(Icons.edit),
          ),
        _ => null,
      },
      body: switch (folders) {
        FoldersLoaded(folders: final list) when list.isEmpty =>
          const _NoFolders(),
        FoldersLoaded(folders: final list) => _FilesBody(list, pull: _pull),
        FoldersUnreadable(:final error) => Center(child: Text(error.text)),
        FoldersLoading() => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Opens a new file in the place for new files, if any folder can take
  /// it; the filters let it through, so it shows once it is written.
  Future<void> _create(List<Folder> all) async {
    final place = ref.read(fileActionsProvider).newFilePlace(all);
    if (place == null) {
      return showSnack(context, 'No folder can be reached right now.');
    }
    final pick = await pickNewFile(
      context,
      ref.read(fileTypesProvider).newFileChoices,
    );
    if (pick == null || !mounted) return;
    ref.read(fileActionsProvider).reveal(place, pick.made.type.support.type);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            FileScreen.fresh(place, made: pick.made, name: pick.name),
      ),
    );
  }
}

class _FilesBody extends ConsumerWidget {
  const _FilesBody(this.folders, {required this.pull});

  final List<Folder> folders;

  /// The key of the files' [PullToRefresh].
  final GlobalKey<PullToRefreshState> pull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(homeFilterProvider);
    final types = ref.watch(fileTypesProvider);
    final contents = ref.watch(folderContentsProvider).value;
    final conflicts = contents?.conflicts;
    final files = filter.of(contents?.files ?? const <ListedFile>[]);
    final orphans = filter.orphansOf(
      conflicts?.orphans ?? const [],
      typeOf: (path) => types.of(path)?.support.type,
    );
    // Conflicts without their file come first in either view.
    final orphanCards = [
      for (final orphan in orphans)
        OrphanCard(orphan, onTap: () => openConflict(context, orphan)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeFilterBar(
          folders,
          conflictCount: (folder) => conflicts?.countIn(folder.id) ?? 0,
        ),
        if (contents != null) FolderProblems(contents, folders: folders),
        Expanded(
          child: PullToRefresh(
            key: pull,
            onRefresh: ref.read(folderContentsProvider.notifier).refresh,
            child: contents == null
                ? const FilledScrollView(child: CircularProgressIndicator())
                : files.isEmpty && orphans.isEmpty
                ? const FilledScrollView(
                    child: EmptyState(
                      icon: Icons.sticky_note_2_outlined,
                      text: 'No files yet.',
                    ),
                  )
                : switch (ref.watch(homeViewProvider)) {
                    HomeView.home => _PinnedAndRecent(
                      files,
                      leading: orphanCards,
                    ),
                    HomeView.all => AllFilesView(
                      files,
                      leading: orphanCards,
                      settings: ref.watch(
                        deviceSettingsProvider.select(
                          (s) => s.requireValue.home,
                        ),
                      ),
                      folders: folders,
                    ),
                  },
          ),
        ),
      ],
    );
  }
}

/// Home's Home view: [leading] cards first, then the pinned and the
/// recently edited of [files], and "Show all" while it leaves some out.
class _PinnedAndRecent extends ConsumerWidget {
  const _PinnedAndRecent(this.files, {required this.leading});

  final List<ListedFile> files;
  final List<Widget> leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(fileSettingsProvider);
    final settings = ref.read(fileSettingsProvider.notifier);
    final home = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.home),
    );
    final recent = recentOf(
      files,
      isPinned: (file) => settings.settingsOf(file.key).pinned,
      count: home.recentCount,
      // Checked on each listing; no timer moves files out while shown.
      since: switch (home.recentDays) {
        null => null,
        final days => DateTime.now().subtract(Duration(days: days)),
      },
    );
    return FileSections(
      leading: leading,
      pinned: [for (final file in recent.pinned) ListedFileCard(file)],
      others: [for (final file in recent.newest) ListedFileCard(file)],
      footer: recent.hidesSome ? const _ShowAll() : null,
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
        ref.watch(folderContentsProvider).value?.conflicts.all.length ?? 0;
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

/// Switches home to All, at the end of Home while Home leaves files out.
class _ShowAll extends ConsumerWidget {
  const _ShowAll();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Center(
      child: OutlinedButton(
        onPressed: () => ref.read(homeViewProvider.notifier).show(HomeView.all),
        child: const Text('Show all'),
      ),
    ),
  );
}

class _NoFolders extends ConsumerWidget {
  const _NoFolders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyState(
      icon: Icons.folder_open_outlined,
      text: 'Add a synced folder to see its files.',
      action: FilledButton.icon(
        onPressed: () => addFolder(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Add folder'),
      ),
    );
  }
}
