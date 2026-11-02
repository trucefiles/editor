import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/empty_state.dart';
import '../../common/filled_scroll_view.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../folders/folder_selection.dart';
import '../../folders/folders_controller.dart';
import '../../folders/ui/folder_badge.dart';
import '../../folders/ui/folder_filter_bar.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../../settings/device_settings_controller.dart';
import 'file_grid.dart';
import 'file_sections.dart';
import 'listed_file_card.dart';
import 'listed_file_row.dart';

/// Opens [AllFilesScreen].
Future<void> openAllFiles(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const AllFilesScreen()),
);

/// All: every file the folders show, filtered by folder, newest
/// first or by name, as cards or a list, as the user picks. Only what is
/// near the screen is built.
class AllFilesScreen extends ConsumerWidget {
  const AllFilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.home),
    );
    final device = ref.read(deviceSettingsProvider.notifier);
    Future<void> changeHome(HomeSettings Function(HomeSettings) change) =>
        device.change((s) => s.copyWith(home: change(s.home)));
    final contents = ref.watch(folderContentsProvider).value;
    final files = filteredBy(
      ref.watch(selectedFolderIdProvider),
      contents?.files ?? const <ListedFile>[],
    );
    final asCards = settings.view == FileView.cards;
    return Scaffold(
      appBar: AppBar(
        title: const Text('All documents'),
        actions: [
          PopupMenuButton<FileOrder>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: settings.order,
            onSelected: (order) =>
                changeHome((settings) => settings.copyWith(order: order)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: FileOrder.time, child: Text('Newest first')),
              PopupMenuItem(value: FileOrder.name, child: Text('By name')),
            ],
          ),
          IconButton(
            tooltip: asCards ? 'Show as list' : 'Show as cards',
            icon: Icon(asCards ? Icons.view_list : Icons.grid_view),
            onPressed: () => changeHome(
              (settings) => settings.copyWith(
                view: asCards ? FileView.list : FileView.cards,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FolderFilterBar(
            ref.watch(foldersProvider).value ?? const [],
            conflictCount: (folder) =>
                contents?.conflicts.countIn(folder.id) ?? 0,
          ),
          Expanded(
            child: PullToRefresh(
              onRefresh: ref.read(folderContentsProvider.notifier).refresh,
              child: switch (contents) {
                null => const FilledScrollView(
                  child: CircularProgressIndicator(),
                ),
                _ when files.isEmpty => const FilledScrollView(
                  child: EmptyState(
                    icon: Icons.sticky_note_2_outlined,
                    text: 'No documents yet.',
                  ),
                ),
                _ => CustomScrollView(
                  // Pulls down even when the files fit, to refresh.
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        asCards ? 12 : 0,
                        0,
                        asCards ? 12 : 0,
                        24,
                      ),
                      sliver: _files(files, settings),
                    ),
                  ],
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Cards built together in by-name order: a few rows in any column
  /// count.
  static const _cardsPerBox = 24;

  /// [files] in the order and view [settings] say, built lazily.
  static Widget _files(List<ListedFile> files, HomeSettings settings) =>
      switch ((settings.order, settings.view)) {
        (FileOrder.time, FileView.cards) => fileGrid(
          files.length,
          (index) => ListedFileCard(files[index]),
        ),
        (FileOrder.time, FileView.list) => SliverList.builder(
          itemCount: files.length,
          itemBuilder: (_, index) => ListedFileRow(files[index]),
        ),
        // Each section's cards come in boxes of a few rows, each built only
        // near the screen: a grid per section would build some cards of every
        // section at once.
        (FileOrder.name, FileView.cards) => _rows([
          for (final section in sectionsByName(files)) ...[
            FilesHeading(_placeOf(section)),
            for (final cards in section.documents.slices(_cardsPerBox))
              fileGridBox([for (final file in cards) ListedFileCard(file)]),
          ],
        ]),
        (FileOrder.name, FileView.list) => _rows([
          for (final section in sectionsByName(files)) ...[
            // Lined up with the rows' text.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilesHeading(_placeOf(section)),
            ),
            for (final file in section.documents) ListedFileRow(file),
          ],
        ]),
      };

  static Widget _rows(List<Widget> rows) => SliverList.builder(
    itemCount: rows.length,
    itemBuilder: (_, index) => rows[index],
  );

  static String _placeOf(FileSection section) =>
      placeName(section.folder, section.subfolder);
}
