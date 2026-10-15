import 'package:flutter/material.dart';

import '../../versions/ui/keep_version_dialog.dart';
import '../../versions/ui/version_comparison.dart';
import '../../versions/ui/version_pane.dart';
import '../note_edit_session.dart';

/// Shows the open note's edits next to the version from elsewhere, so the
/// user sees both before keeping one. Closes once the session no longer
/// waits for that choice, whoever settled it.
class ChangedElsewhereScreen extends StatefulWidget {
  const ChangedElsewhereScreen(this.session, {super.key});

  final NoteEditSession session;

  @override
  State<ChangedElsewhereScreen> createState() => _ChangedElsewhereScreenState();
}

class _ChangedElsewhereScreenState extends State<ChangedElsewhereScreen> {
  bool _closed = false;

  NoteEditSession get _session => widget.session;

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
    if (_session.state == EditState.changedElsewhere) {
      setState(() {});
    } else if (!_closed && mounted) {
      _closed = true;
      if (ModalRoute.of(context) case final route?) {
        Navigator.removeRoute(context, route);
      }
    }
  }

  Future<void> _keepMine() async {
    if (await _confirm('The other version is replaced by yours.')) {
      await _session.keepMine();
    }
  }

  Future<void> _keepTheirs() async {
    if (await _confirm('Your edits are replaced by the other version.')) {
      _session.loadTheirs();
    }
  }

  /// Only while the choice is still open: it may have been settled while
  /// the dialog showed.
  Future<bool> _confirm(String message) async =>
      await confirmKeepVersion(context, '$message No backup is kept.') &&
      _session.state == EditState.changedElsewhere;

  @override
  Widget build(BuildContext context) {
    final theirs = _session.theirs;
    return Scaffold(
      appBar: AppBar(title: const Text('Changed on another device or app')),
      body: theirs == null
          ? const SizedBox.shrink()
          : VersionComparison(
              first: VersionPane(
                label: 'Your version',
                modified: null,
                text: _session.text,
                compareTo: theirs.file.text,
                keepLabel: 'Keep this',
                onKeep: _keepMine,
              ),
              second: VersionPane(
                label: 'Other version',
                modified: theirs.modified,
                text: theirs.file.text,
                compareTo: _session.text,
                keepLabel: 'Keep this',
                onKeep: _keepTheirs,
              ),
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
