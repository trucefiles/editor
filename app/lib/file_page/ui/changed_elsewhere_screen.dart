import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../backups/ui/both_backed_up_text.dart';
import '../../common/snack.dart';
import '../../versions/ui/compare_app_bar.dart';
import '../../versions/ui/version_chooser.dart';
import '../../versions/ui/version_content.dart';
import '../file_controller.dart';

/// Shows the open file's edits next to the version from elsewhere,
/// in the same view as a sync conflict, so the user sees both before
/// keeping one. Closes once the file no longer waits for that
/// choice, whoever settled it.
class ChangedElsewhereScreen extends StatefulWidget {
  const ChangedElsewhereScreen(this.controller, {super.key});

  /// The open file's view model.
  final FileController controller;

  @override
  State<ChangedElsewhereScreen> createState() => _ChangedElsewhereScreenState();
}

class _ChangedElsewhereScreenState extends State<ChangedElsewhereScreen> {
  bool _closed = false;

  /// The version a pick was sent against, while it is carried out.
  Seen<ReadVersion>? _picking;

  late final StreamSubscription<FileEvent> _notices;

  FileSession get _session => widget.controller.session;

  /// The version from elsewhere, while the choice is open.
  Seen<ReadVersion>? get _theirs => switch (_session.status) {
    ChangedElsewhere(:final theirs) => theirs,
    _ => null,
  };

  /// Whether the edits and a version from elsewhere can be merged, as
  /// last asked; asked again for each new version.
  ({ReadVersion version, bool merges})? _merging;

  /// Whether the edits and [theirs] can be merged, as far as known yet.
  bool _merges(Seen<ReadVersion> theirs) => switch (_merging) {
    (:final version, :final merges) when version == theirs.version => merges,
    _ => false,
  };

  /// Asks whether the edits and the version shown merge, once per
  /// version.
  void _askMerges() {
    final theirs = _theirs;
    if (theirs == null || _merging?.version == theirs.version) return;
    _merging = (version: theirs.version, merges: false);
    unawaited(
      _session.mergesWith(theirs).then((merges) {
        if (!mounted || _merging?.version != theirs.version) return;
        setState(() => _merging = (version: theirs.version, merges: merges));
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSessionChanged);
    _askMerges();
    _notices = _session.fileNotices.listen((notice) {
      if (notice is! PickNotKept || !mounted) return;
      setState(() => _picking = null);
      showSnack(
        context,
        "That didn't work, so nothing changed. Please try again.",
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
      _askMerges();
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
  void _keep(VersionSide side, Seen<ReadVersion> seen) => _pick(switch (side) {
    VersionSide.current => PickChoice.theirs,
    VersionSide.other => PickChoice.mine,
  }, seen);

  /// Sends [choice] against [seen], only while the choice is still open.
  void _pick(PickChoice choice, Seen<ReadVersion> seen) {
    if (_theirs == null) return;
    setState(() => _picking = seen);
    _session.pick(choice, theirs: seen, rev: _session.rev);
  }

  @override
  Widget build(BuildContext context) {
    final theirs = _theirs;
    final file = _session.file;
    return Scaffold(
      appBar: compareAppBar(
        folder: file.folder,
        file: _session.path,
        reason: 'Changed in the folder while you were editing',
      ),
      body: theirs == null
          ? const SizedBox.shrink()
          : VersionChooser(
              current: ShownVersion(
                label: 'Current version',
                content: SavedText(
                  theirs.text,
                  theirs.version.read.listed.modified,
                ),
                keepLabel: 'Keep this',
                keptMessage: 'Your edits are dropped. $bothBackedUp',
              ),
              other: ShownVersion(
                label: 'Your edits',
                content: EditorText(_session.text),
                keepLabel: 'Keep this',
                keptMessage:
                    'Your edits replace the current version. $bothBackedUp',
              ),
              // This device's edits are the base: their own lines green.
              base: VersionSide.other,
              enabled: _picking == null,
              // This build's version: the one shown when the user taps.
              onKeep: (side) => _keep(side, theirs),
              onMerge: _merges(theirs)
                  ? () => _pick(PickChoice.merged, theirs)
                  : null,
            ),
    );
  }
}

/// Opens the comparison for [controller]'s file, which waits for the
/// user's choice; the edits are sent to be kept first, so the comparison
/// shows them all.
Future<void> openChangedElsewhere(
  BuildContext context,
  FileController controller,
) async {
  await controller.session.secure(SecureReason.hide);
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => ChangedElsewhereScreen(controller)),
  );
}
