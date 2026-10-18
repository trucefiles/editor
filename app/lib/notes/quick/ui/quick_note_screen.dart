import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../../common/error_text.dart';
import '../../../common/snack.dart';
import '../../../folders/folders_controller.dart';
import '../../../folders/note_folder.dart';
import '../../../folders/ui/folder_badge.dart';
import '../../../scan/folder_scans_controller.dart';
import '../../note_actions.dart';
import '../../note_place.dart';
import '../../ui/line_break_formatter.dart';
import '../../ui/note_place_dialog.dart';
import '../quick_note_controller.dart';
import '../quick_note_drafts_provider.dart';

/// Starts a note at once: the user types, and may pick its folder on the
/// way. On leaving, the note goes into its folder, named after its first
/// line; until then it is kept on this device only.
class QuickNoteScreen extends ConsumerStatefulWidget {
  const QuickNoteScreen({super.key});

  @override
  ConsumerState<QuickNoteScreen> createState() => _QuickNoteScreenState();
}

class _QuickNoteScreenState extends ConsumerState<QuickNoteScreen> {
  late final _controller = QuickNoteController(
    ref.read(quickNoteDraftsProvider),
    ref.read(noteActionsProvider),
  );
  final _text = TextEditingController();
  late final AppLifecycleListener _lifecycle;
  bool _started = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: _controller.secure,
      onExitRequested: () async {
        await _controller.secure();
        return AppExitResponse.exit;
      },
    );
    unawaited(_start());
  }

  Future<void> _start() async {
    final text = await _controller.start();
    if (!mounted) return;
    _text
      ..text = text
      ..addListener(() => _controller.edit(_text.text));
    setState(() => _started = true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    _text.dispose();
    super.dispose();
  }

  NoteActions get _actions => ref.read(noteActionsProvider);

  List<NoteFolder> get _folders =>
      _actions.reachableOf(ref.read(foldersProvider).value ?? const []);

  /// Puts the note into its folder and leaves; if that fails, it stays on
  /// this device and the user is told how to go on with it.
  Future<void> _leave() async {
    if (_leaving || !_started) return;
    _leaving = true;
    final messenger = ScaffoldMessenger.of(context);
    final folders = _folders;
    if (folders.isEmpty) {
      await _controller.secure();
      _close();
      return messenger.showHint(
        'No folder can be reached. The note is kept on this device; '
        'New note goes on with it.',
      );
    }
    final place = _controller.placeAmong(folders);
    final filed = await _controller.file(folders);
    _close();
    if (filed case Err(:final error)) {
      messenger.showHint(
        "Couldn't save the note in ${place.folder.name}: ${error.text} "
        'It is kept on this device; New note goes on with it.',
      );
    }
  }

  void _close() {
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickPlace(NotePlace current) async {
    // Change events don't tell about new empty subfolders; a rescan finds
    // them, so the dialog offers them.
    await ref.read(folderScansProvider.notifier).refresh();
    if (!mounted) return;
    final folders = _folders;
    if (folders.isEmpty) return;
    final picked = await showNotePlaceDialog(
      context,
      title: 'Save in',
      action: 'OK',
      folders: folders,
      initial: current,
      subfoldersOf: _actions.subfoldersOf,
    );
    if (picked != null) _controller.pick(picked);
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(foldersProvider)
      ..watch(folderScansProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('New note')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _placeChip(),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _text,
                enabled: _started,
                autofocus: true,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                inputFormatters: [lineBreakFormatter],
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Note',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeChip() {
    final folders = _folders;
    if (folders.isEmpty) return const SizedBox.shrink();
    final place = _controller.placeAmong(folders);
    return Tooltip(
      message: 'Folder',
      child: ActionChip(
        label: FolderBadge(place.folder, subfolder: place.subfolder),
        onPressed: () => _pickPlace(place),
      ),
    );
  }
}
