import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../documents/ui/document_grid.dart';
import '../../documents/ui/listed_document_card.dart';
import '../search_controller.dart';

/// Search across all folders, updated as the user types and as texts are
/// read.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:query, :found, :complete) = ref.watch(searchProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: ref.read(searchProvider.notifier).find,
          decoration: const InputDecoration(
            hintText: 'Search all documents',
            border: InputBorder.none,
          ),
        ),
        bottom: complete
            ? null
            : const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(
                  semanticsLabel: 'Reading documents',
                ),
              ),
      ),
      body: switch ((query.trim().isEmpty, found.isEmpty)) {
        (true, _) => const SizedBox.shrink(),
        (false, true) when complete => const EmptyState(
          icon: Icons.search_off,
          text: 'Nothing found.',
        ),
        (false, true) => const SizedBox.shrink(),
        (false, false) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: documentGrid(
                found.length,
                (index) => ListedDocumentCard(found[index]),
              ),
            ),
          ],
        ),
      },
    );
  }
}
