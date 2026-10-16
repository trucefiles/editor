import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/empty_state.dart';
import '../../notes/note.dart';
import '../../notes/note_settings_controller.dart';
import '../../notes/ui/note_card.dart';
import '../../notes/ui/note_grid.dart';
import '../../notes/ui/pin_or_color_sheet.dart';
import '../../scan/folder_scans_controller.dart';
import '../note_search.dart';

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
    final notes = scans?.notes ?? const <Note>[];
    ref.watch(noteSettingsProvider);
    final settings = ref.read(noteSettingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search all notes',
            border: InputBorder.none,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _query,
        builder: (context, _) {
          if (_query.text.trim().isEmpty) return const SizedBox.shrink();
          final found = searchNotes(notes, _query.text);
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
                sliver: noteGrid([
                  for (final note in found)
                    NoteCard(
                      note,
                      mark: scans?.markOf(note.key) ?? NoteMark.none,
                      pinned: settings.settingsOf(note.key).pinned,
                      onTap: () => openNote(context, note),
                      onMark: () => editPinOrColor(context, ref, note),
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
