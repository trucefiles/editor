import 'package:flutter/material.dart';

import '../../conflicts/ui/version_comparison.dart';
import '../../conflicts/ui/version_pane.dart';
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

  void _onSessionChanged() {
    if (_session.state == EditState.changedElsewhere) {
      setState(() {});
    } else if (!_closed && mounted) {
      _closed = true;
      Navigator.pop(context);
    }
  }

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
                onKeep: _session.keepMine,
              ),
              second: VersionPane(
                label: 'Other version',
                modified: theirs.modified,
                text: theirs.file.text,
                compareTo: _session.text,
                keepLabel: 'Keep this',
                onKeep: _session.loadTheirs,
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
