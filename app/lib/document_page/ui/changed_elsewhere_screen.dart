import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../backups/backup_retention.dart';
import '../../common/snack.dart';
import '../../documents/document_version.dart';
import '../../versions/ui/compare_app_bar.dart';
import '../../versions/ui/version_chooser.dart';
import '../document_controller.dart';
import '../document_session.dart';

/// Shows the open document's edits next to the version from elsewhere,
/// in the same view as a sync conflict, so the user sees both before
/// keeping one. Closes once the document no longer waits for that
/// choice, whoever settled it.
class ChangedElsewhereScreen extends StatefulWidget {
  const ChangedElsewhereScreen(this.controller, {super.key});

  /// The open document's view model.
  final DocumentController controller;

  @override
  State<ChangedElsewhereScreen> createState() => _ChangedElsewhereScreenState();
}

class _ChangedElsewhereScreenState extends State<ChangedElsewhereScreen> {
  bool _closed = false;

  /// The version a pick was sent against, while it is carried out.
  Seen? _picking;

  late final StreamSubscription<FileEvent> _notices;

  DocumentSession get _session => widget.controller.session;

  /// The version from elsewhere, while the choice is open.
  Seen? get _theirs => switch (_session.status) {
    ChangedElsewhere(:final theirs) => theirs,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSessionChanged);
    _notices = _session.fileNotices.listen((notice) {
      if (notice is! PickNotKept || !mounted) return;
      setState(() => _picking = null);
      showSnack(
        context,
        "Nothing was changed: a backup couldn't be made, or the document "
        'changed again. Please choose again.',
      );
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSessionChanged);
    unawaited(_notices.cancel());
    super.dispose();
  }

  /// Removes this screen's own route, not whatever is on top (e.g. a
  /// dialog).
  void _onSessionChanged() {
    final theirs = _theirs;
    if (theirs != null) {
      // A newer version from elsewhere: the pick against the old one
      // changes nothing, so the user picks again.
      if (_picking != null && _picking?.version != theirs.version) {
        _picking = null;
      }
      setState(() {});
    } else if (!_closed && mounted) {
      _closed = true;
      if (ModalRoute.of(context) case final route?) {
        Navigator.removeRoute(context, route);
      }
    }
  }

  /// Only while the choice is still open: it may have been settled while
  /// the user confirmed. [seen]: the version shown when the user tapped.
  void _keep(VersionSide side, Seen seen) {
    if (_theirs == null) return;
    setState(() => _picking = seen);
    _session.pick(
      switch (side) {
        VersionSide.current => PickChoice.theirs,
        VersionSide.other => PickChoice.mine,
      },
      theirs: seen,
      rev: _session.rev,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theirs = _theirs;
    final file = _session.file;
    return Scaffold(
      appBar: compareAppBar(
        folder: file.folder,
        file: file.pathFor(_session.text),
        reason: 'Changed on another device or app while you edited',
      ),
      body: theirs == null
          ? const SizedBox.shrink()
          : VersionChooser(
              current: ShownVersion(
                label: 'Current version',
                modified: documentOf(theirs.version).document.modified,
                text: theirs.text,
                keepLabel: 'Keep this',
                keptMessage: 'Your edits are dropped. $bothBackedUp',
              ),
              other: ShownVersion(
                label: 'Your edits',
                text: _session.text,
                keepLabel: 'Keep this',
                keptMessage:
                    'The current version is replaced by your edits. '
                    '$bothBackedUp',
              ),
              enabled: _picking == null,
              // This build's version: the one shown when the user taps.
              onKeep: (side) => _keep(side, theirs),
            ),
    );
  }
}

/// Opens the comparison for [controller]'s document, which waits for the
/// user's choice; the edits are sent to be kept first, so the comparison
/// shows them all.
Future<void> openChangedElsewhere(
  BuildContext context,
  DocumentController controller,
) async {
  await controller.session.secure(SecureReason.hide);
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => ChangedElsewhereScreen(controller)),
  );
}
