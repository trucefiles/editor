import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../checklist/checklist_editor.dart';
import '../../checklist/checklist_settings.dart';
import '../../checklist/ui/checklist_view.dart';
import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../folders/ui/folder_badge.dart';
import '../note.dart';
import '../note_edit_session.dart';
import '../note_files.dart';
import '../note_title.dart';
import '../notes_controller.dart';

/// Editor for one note, as plain text or as a checklist. Saves as the user
/// types.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen(this.note, {this.autofocus = false, super.key});

  final Note note;

  /// Puts the cursor in the text right away, e.g. for a new note. Off by
  /// default, so opening a note on a phone does not pop up the keyboard.
  final bool autofocus;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final NoteFiles _files = ref.read(noteFilesProvider(widget.note.folder));
  late final NotesController _notes = ref.read(notesProvider.notifier);
  late final _session = NoteEditSession(widget.note, _files);
  late final _text = TextEditingController(text: _session.text);
  late final AppLifecycleListener _lifecycle;
  late final _checklist = ChecklistEditor(_session);
  late bool _listView = _checklist.list.hasItems;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => _session.edit(_text.text));
    _session.addListener(_onSessionChanged);
    _lifecycle = AppLifecycleListener(onHide: _session.flush);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _checklist.dispose();
    _session.removeListener(_onSessionChanged);
    final session = _session;
    unawaited(
      session.flush().whenComplete(() {
        session.dispose();
        unawaited(_notes.refresh());
      }),
    );
    _text.dispose();
    super.dispose();
  }

  /// Shows text the session took from the file (rescan or "load theirs").
  void _onSessionChanged() {
    if (_text.text != _session.text) {
      final offset = _text.selection.baseOffset.clamp(0, _session.text.length);
      _text.value = TextEditingValue(
        text: _session.text,
        selection: TextSelection.collapsed(offset: offset),
      );
    }
    setState(() {});
  }

  Future<void> _delete() async {
    await _session.flush();
    final note = _session.note;
    final text = _session.text;
    final deleted = await _files.delete(note);
    if (!mounted) return;
    if (deleted case Err(:final error)) {
      showSnack(context, error.text);
      return;
    }
    final files = _files;
    final notes = _notes;
    showSnack(
      context,
      'Note deleted',
      actionLabel: 'Undo',
      onAction: () async {
        await files.restore(note, text);
        await notes.refresh();
      },
    );
    Navigator.pop(context);
  }

  Widget _menu() {
    final separateDone = ref.watch(doneSectionProvider);
    return PopupMenuButton<VoidCallback>(
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        if (_listView) ...[
          PopupMenuItem(value: _clearDone, child: const Text('Clear done')),
          CheckedPopupMenuItem(
            value: () => ref
                .read(doneSectionProvider.notifier)
                .set(enabled: !separateDone),
            checked: separateDone,
            child: const Text('Done section'),
          ),
        ],
        PopupMenuItem(value: _delete, child: const Text('Delete note')),
      ],
    );
  }

  void _clearDone() {
    final before = _checklist.clearDone();
    showSnack(
      context,
      'Done items cleared',
      actionLabel: 'Undo',
      onAction: () => _checklist.undo(before),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notesProvider, (_, next) {
      if (next.value case final snapshot?
          when !snapshot.failedFolders.keys.any(
            (folder) => folder.id == widget.note.folder.id,
          )) {
        _session.onRescan(
          snapshot.find(widget.note.key),
          scannedAt: snapshot.startedAt,
        );
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: _text,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                noteTitle(_text.text, widget.note.path),
                overflow: TextOverflow.ellipsis,
              ),
              FolderBadge(widget.note.folder),
            ],
          ),
        ),
        actions: [
          _SaveIndicator(_session.state),
          IconButton(
            tooltip: _listView ? 'Text view' : 'List view',
            icon: Icon(_listView ? Icons.notes : Icons.checklist),
            onPressed: () => setState(() => _listView = !_listView),
          ),
          _menu(),
        ],
      ),
      body: Column(
        children: [
          if (_session.state == EditState.changedElsewhere)
            _Banner(
              message: 'This note changed on another device or app.',
              actions: {
                'Load theirs': _session.loadTheirs,
                'Keep mine': _session.keepMine,
              },
            ),
          if (_session.state == EditState.deletedElsewhere)
            _Banner(
              message:
                  'This note was deleted on another device or app. '
                  'Your text is kept here but not saved.',
              actions: {
                'Restore with my text': _session.restoreMine,
                'Close': () => Navigator.pop(context),
              },
            ),
          if (_session.state == EditState.saveFailed)
            _Banner(
              message: 'Saving failed. Your text is kept here.',
              actions: {'Retry': _session.flush},
            ),
          Expanded(
            child: _listView
                ? ChecklistView(_checklist)
                : TextField(
                    controller: _text,
                    maxLines: null,
                    expands: true,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator(this.state);

  final EditState state;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (state) {
      EditState.saved => (Icons.cloud_done_outlined, 'Saved'),
      EditState.unsaved => (Icons.edit_outlined, 'Saving…'),
      EditState.changedElsewhere => (Icons.sync_problem, 'Changed elsewhere'),
      EditState.deletedElsewhere => (Icons.sync_problem, 'Deleted elsewhere'),
      EditState.saveFailed => (Icons.error_outline, 'Not saved'),
    };
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(icon),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.actions});

  final String message;
  final Map<String, FutureOr<void> Function()> actions;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message),
      actions: [
        for (final MapEntry(key: label, value: action) in actions.entries)
          TextButton(onPressed: action, child: Text(label)),
      ],
    );
  }
}
