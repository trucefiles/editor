import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

import '../documents/documents_wiring.dart';
import '../folder_state/folder_state_controller.dart';
import 'text_search_wiring.dart';

/// What search shows: the documents the [query] finds, and whether every
/// text was read ([complete]); until then, more may show.
typedef SearchResults = ({String query, List<Document> found, bool complete});

final searchProvider =
    NotifierProvider.autoDispose<DocumentSearchController, SearchResults>(
      DocumentSearchController.new,
    );

/// One search, while its screen is open: over every document the folders
/// show when it opens, whatever the folder filter. Their texts are read
/// once, in the background, and dropped when it closes; files changed
/// meanwhile are not read again.
class DocumentSearchController extends Notifier<SearchResults> {
  late OpenSearch<Document> _search;

  @override
  SearchResults build() {
    final search = _search = ref.read(openTextSearchProvider)(
      searchablesOf(
        ref.read(folderContentsProvider).value?.documents ?? const [],
        filesOf: (folder) => ref.read(folderFilesProvider).of(folder),
      ),
    );
    final changes = search.changes.listen((_) => find(state.query));
    ref.onDispose(() {
      unawaited(changes.cancel());
      unawaited(search.close());
    });
    return _resultsOf('');
  }

  /// Shows what [query] finds.
  void find(String query) => state = _resultsOf(query);

  SearchResults _resultsOf(String query) =>
      (query: query, found: _search.find(query), complete: _search.complete);
}
