import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../file_types/file_types.dart';
import '../files/files_wiring.dart';
import '../folder_state/folder_state_controller.dart';
import 'text_search_wiring.dart';

/// What search shows: the files the [query] finds, and whether every
/// text was read ([complete]); until then, more may show.
typedef SearchResults = ({String query, List<ListedFile> found, bool complete});

final searchProvider =
    NotifierProvider.autoDispose<FileSearchController, SearchResults>(
      FileSearchController.new,
    );

/// One search, while its screen is open: over every file the folders
/// show when it opens, whatever the folder filter. Their texts are read
/// once, in the background, and dropped when it closes; files changed
/// meanwhile are not read again.
class FileSearchController extends Notifier<SearchResults> {
  late OpenSearch<ListedFile> _search;

  @override
  SearchResults build() {
    final search = _search = ref.read(openTextSearchProvider)(
      searchablesOf(
        ref.read(folderContentsProvider).value?.files ?? const [],
        filesOf: (folder) => ref.read(fileAccessProvider).of(folder),
        types: ref.read(fileTypesProvider),
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
