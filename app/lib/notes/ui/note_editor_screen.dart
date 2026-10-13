import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../checklist/checklist_editor.dart';
import '../../checklist/checklist_settings.dart';
import '../../checklist/ui/checklist_view.dart';
import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../conflicts/conflicts_controller.dart';
import '../../conflicts/ui/conflict_banner.dart';
import '../../folders/ui/folder_badge.dart';
import '../../markdown/markdown_view.dart';
import '../note.dart';
import '../note_edit_session.dart';
import '../note_files.dart';
import '../note_title.dart';
import '../note_view.dart';
import '../note_views_controller.dart';
import '../notes_controller.dart';
import 'note_view_button.dart';

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
  // Read up front: dispose() needs it, and ref is unusable by then.
  late final NotesController _notes;
  late final _session = NoteEditSession(widget.note, _files);
  late final _text = TextEditingController(text: _session.text);
  late final AppLifecycleListener _lifecycle;
  late final _checklist = ChecklistEditor(_session);
  late final NoteViewsController _views;
  bool _closed = false;

  /// The note's last view on this device; else a list if it has items.
  late NoteView _view =
      _views.viewOf(widget.note.key) ??
      (_checklist.list.hasItems ? NoteView.list : NoteView.text);

  @override
  void initState() {
    super.initState();
    _notes = ref.read(notesProvider.notifier);
    _views = ref.read(noteViewsProvider.notifier);
    _text.addListener(() => _session.edit(_text.text));
    _session.addListener(_onSessionChanged);
    _lifecycle = AppLifecycleListener(
      onHide: _session.secure,
      onExitRequested: _onExitRequested,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _checklist.dispose();
    _session.removeListener(_onSessionChanged);
    final session = _session;
    unawaited(
      session.secure().whenComplete(() {
        session.dispose();
        unawaited(_notes.refresh());
      }),
    );
    _text.dispose();
    super.dispose();
  }

  /// Shows text the session took from the file (rescan or "load theirs"),
  /// and closes once the edits were kept as a conflict copy.
  void _onSessionChanged() {
    if (_session.state == EditState.keptAsConflict) {
      _close(message: 'Your edits were kept as a conflict copy');
      return;
    }
    if (_text.text != _session.text) {
      final offset = _text.selection.baseOffset.clamp(0, _session.text.length);
      _text.value = TextEditingValue(
        text: _session.text,
        selection: TextSelection.collapsed(offset: offset),
      );
    }
    setState(() {});
  }

  /// Leaves only once the edits are in the file or in a conflict copy;
  /// asks if they can be kept nowhere.
  Future<void> _leave() async {
    final kept = await _session.secure();
    if (!mounted) return;
    kept ? _close() : await _askToDiscard();
  }

  Future<AppExitResponse> _onExitRequested() async {
    if (await _session.secure()) return AppExitResponse.exit;
    if (mounted) unawaited(_askToDiscard());
    return AppExitResponse.cancel;
  }

  Future<void> _askToDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Your edits can't be saved"),
        content: const Text(
          'Neither the note nor a conflict copy could be written. '
          'Stay to copy your text elsewhere, or discard it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
        ],
      ),
    );
    if (discard ?? false) _close();
  }

  void _close({String? message}) {
    if (_closed || !mounted) return;
    _closed = true;
    if (message != null) showSnack(context, message);
    Navigator.pop(context);
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
        if (_view == NoteView.list) ...[
          PopupMenuItem(value: _clearDone, child: const Text('Clear done')),
          PopupMenuItem(
            value: () => ref
                .read(doneSectionProvider.notifier)
                .set(enabled: !separateDone),
            child: _ToggleLabel('Done section', on: separateDone),
          ),
        ],
        PopupMenuItem(value: _delete, child: const Text('Delete note')),
      ],
    );
  }

  void _showView(NoteView view) {
    setState(() => _view = view);
    unawaited(_views.remember(widget.note.key, view));
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
    return PopScope(
      canPop:
          _session.state == EditState.saved ||
          _session.state == EditState.keptAsConflict,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
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
          NoteViewButton(view: _view, onChanged: _showView),
          _menu(),
        ],
      ),
      body: Column(
        children: [
          if (ref.watch(conflictsProvider).value?.forNote(widget.note.key)
              case final conflict?)
            ConflictBanner(conflict),
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
                  'Your text is kept here; closing keeps it as a conflict.',
              actions: {
                'Restore with my text': _session.restoreMine,
                'Close': _leave,
              },
            ),
          if (_session.state == EditState.saveFailed)
            _Banner(
              message: 'Saving failed. Your text is kept here.',
              actions: {'Retry': _session.flush},
            ),
          Expanded(
            child: switch (_view) {
              NoteView.list => ChecklistView(_checklist),
              NoteView.rendered => MarkdownView(_session.text),
              NoteView.text => TextField(
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
            },
          ),
        ],
      ),
    );
  }
}

/// A menu label with a checkbox icon that shows on and off alike, so it
/// lines up with plain menu items.
class _ToggleLabel extends StatelessWidget {
  const _ToggleLabel(this.label, {required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Icon(on ? Icons.check_box : Icons.check_box_outline_blank),
    ],
  );
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
      EditState.keptAsConflict => (Icons.sync_problem, 'Kept as conflict'),
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
