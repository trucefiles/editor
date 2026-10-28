import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/empty_state.dart';
import '../../documents/document.dart';
import '../../documents/document_settings_controller.dart';
import '../../documents/ui/document_card.dart';
import '../../documents/ui/document_grid.dart';
import '../../documents/ui/pin_or_color_sheet.dart';
import '../../scan/folder_scans_controller.dart';
import '../document_search.dart';

/// Full-text search across all folders, updated as the user types.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scans = ref.watch(folderScansProvider).value;
    final documents = scans?.documents ?? const <Document>[];
    ref.watch(documentSettingsProvider);
    final settings = ref.read(documentSettingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search all documents',
            border: InputBorder.none,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _query,
        builder: (context, _) {
          if (_query.text.trim().isEmpty) return const SizedBox.shrink();
          final found = searchNotes(documents, _query.text);
          if (found.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              text: 'Nothing found.',
            );
          }
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: documentGrid([
                  for (final document in found)
                    DocumentCard(
                      document,
                      mark: scans?.markOf(document.key) ?? DocumentMark.none,
                      settings: settings.settingsOf(document.key),
                      onTap: () => openNote(context, document),
                      onMark: () => editPinOrColor(context, ref, document),
                    ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
