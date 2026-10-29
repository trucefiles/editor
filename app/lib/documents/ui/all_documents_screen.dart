import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../common/filled_scroll_view.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../folders/folder_selection.dart';
import '../../folders/folders_controller.dart';
import '../../folders/ui/folder_badge.dart';
import '../../folders/ui/folder_filter_bar.dart';
import '../../refresh/ui/pull_to_refresh.dart';
import '../document.dart';
import '../home/home_lists.dart';
import '../home/home_settings.dart';
import '../home/home_settings_controller.dart';
import 'document_grid.dart';
import 'document_sections.dart';
import 'listed_document_card.dart';
import 'listed_document_row.dart';

/// Opens [AllDocumentsScreen].
Future<void> openAllDocuments(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const AllDocumentsScreen()),
);

/// All: every document the folders show, filtered by folder, newest
/// first or by name, as cards or a list, as the user picks. Only what is
/// near the screen is built.
class AllDocumentsScreen extends ConsumerWidget {
  const AllDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(homeSettingsProvider).value ?? HomeSettings.standard;
    final home = ref.read(homeSettingsProvider.notifier);
    final contents = ref.watch(folderContentsProvider).value;
    final documents = filteredBy(
      ref.watch(selectedFolderIdProvider),
      contents?.documents ?? const <Document>[],
    );
    final asCards = settings.view == DocumentView.cards;
    return Scaffold(
      appBar: AppBar(
        title: const Text('All documents'),
        actions: [
          PopupMenuButton<DocumentOrder>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: settings.order,
            onSelected: (order) =>
                home.change((settings) => settings.copyWith(order: order)),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: DocumentOrder.time,
                child: Text('Newest first'),
              ),
              PopupMenuItem(value: DocumentOrder.name, child: Text('By name')),
            ],
          ),
          IconButton(
            tooltip: asCards ? 'Show as list' : 'Show as cards',
            icon: Icon(asCards ? Icons.view_list : Icons.grid_view),
            onPressed: () => home.change(
              (settings) => settings.copyWith(
                view: asCards ? DocumentView.list : DocumentView.cards,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FolderFilterBar(
            ref.watch(loadedFoldersProvider).value ?? const [],
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
                _ when documents.isEmpty => const FilledScrollView(
                  child: EmptyState(
                    icon: Icons.sticky_note_2_outlined,
                    text: 'No documents yet.',
                  ),
                ),
                _ => CustomScrollView(
                  // Pulls down even when the documents fit, to refresh.
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        asCards ? 12 : 0,
                        0,
                        asCards ? 12 : 0,
                        24,
                      ),
                      sliver: _documents(documents, settings),
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

  /// [documents] in the order and view [settings] say, built lazily.
  static Widget _documents(
    List<Document> documents,
    HomeSettings settings,
  ) => switch ((settings.order, settings.view)) {
    (DocumentOrder.time, DocumentView.cards) => documentGrid(
      documents.length,
      (index) => ListedDocumentCard(documents[index]),
    ),
    (DocumentOrder.time, DocumentView.list) => SliverList.builder(
      itemCount: documents.length,
      itemBuilder: (_, index) => ListedDocumentRow(documents[index]),
    ),
    // A lazy grid that something follows breaks scrolling (see
    // documentGrid), so each section's cards come in boxes of a few rows,
    // each built only near the screen.
    (DocumentOrder.name, DocumentView.cards) => _rows([
      for (final section in sectionsByName(documents)) ...[
        DocumentsHeading(_placeOf(section)),
        for (final cards in section.documents.slices(_cardsPerBox))
          documentGridBox([
            for (final document in cards) ListedDocumentCard(document),
          ]),
      ],
    ]),
    (DocumentOrder.name, DocumentView.list) => _rows([
      for (final section in sectionsByName(documents)) ...[
        // Lined up with the rows' text.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DocumentsHeading(_placeOf(section)),
        ),
        for (final document in section.documents) ListedDocumentRow(document),
      ],
    ]),
  };

  static Widget _rows(List<Widget> rows) => SliverList.builder(
    itemCount: rows.length,
    itemBuilder: (_, index) => rows[index],
  );

  static String _placeOf(DocumentSection section) =>
      placeName(section.folder, section.subfolder);
}
