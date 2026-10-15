import 'package:flutter/material.dart';

import '../../common/snack.dart';
import '../../versions/ui/compare_app_bar.dart';
import '../../versions/ui/version_chooser.dart';
import '../note_edit_session.dart';

/// Shows the open note's edits next to the version from elsewhere, in the
/// same view as a sync conflict, so the user sees both before keeping one.
/// Closes once the session no longer waits for that choice, whoever
/// settled it.
class ChangedElsewhereScreen extends StatefulWidget {
  const ChangedElsewhereScreen(this.session, {super.key});

  final NoteEditSession session;

  @override
  State<ChangedElsewhereScreen> createState() => _ChangedElsewhereScreenState();
}

class _ChangedElsewhereScreenState extends State<ChangedElsewhereScreen> {
  bool _closed = false;
  bool _busy = false;

  NoteEditSession get _session => widget.session;

  bool get _asking => _session.state == EditState.changedElsewhere;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// Removes this screen's own route, not whatever is on top (e.g. a
  /// dialog).
  void _onSessionChanged() {
    if (_asking) {
      setState(() {});
    } else if (!_closed && mounted) {
      _closed = true;
      if (ModalRoute.of(context) case final route?) {
        Navigator.removeRoute(context, route);
      }
    }
  }

  /// Only while the choice is still open: it may have been settled while
  /// the user confirmed.
  Future<void> _keep(VersionSide side) async {
    if (!_asking) return;
    setState(() => _busy = true);
    final kept = switch (side) {
      VersionSide.current => await _session.loadTheirs(),
      VersionSide.other => await _session.keepMine(),
    };
    if (!mounted) return;
    setState(() => _busy = false);
    if (!kept) {
      showSnack(context, 'No backup could be made, so nothing changed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _session.note;
    final theirs = _session.theirs;
    return Scaffold(
      appBar: compareAppBar(
        folder: note.folder,
        file: note.path,
        note: 'Changed on another device or app while you edited',
      ),
      body: theirs == null
          ? const SizedBox.shrink()
          : VersionChooser(
              current: ShownVersion(
                label: 'Current version',
                modified: theirs.modified,
                text: theirs.file.text,
                keepLabel: 'Keep this',
                keptMessage: 'Your edits are dropped.',
              ),
              other: ShownVersion(
                label: 'Your edits',
                text: _session.text,
                keepLabel: 'Keep this',
                keptMessage: 'The current version is replaced by your edits.',
              ),
              enabled: !_busy,
              onKeep: _keep,
            ),
    );
  }
}

/// Opens the comparison for [session], which waits for the user's choice.
Future<void> openChangedElsewhere(
  BuildContext context,
  NoteEditSession session,
) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => ChangedElsewhereScreen(session)),
);
