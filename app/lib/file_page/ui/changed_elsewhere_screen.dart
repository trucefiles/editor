import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../backups/ui/both_backed_up_text.dart';
import '../../common/snack.dart';
import '../../versions/ui/compare_app_bar.dart';
import '../../versions/ui/version_chooser.dart';
import '../../versions/ui/version_content.dart';
import '../changed_elsewhere_controller.dart';
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
  late final _choice = ChangedElsewhereController(widget.controller);
  late final StreamSubscription<void> _notKept;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _choice.addListener(_onChoiceChanged);
    _notKept = _choice.notKept.listen((_) {
      if (!mounted) return;
      showSnack(
        context,
        "That didn't work, so nothing changed. Please try again.",
      );
    });
  }

  @override
  void dispose() {
    _choice.removeListener(_onChoiceChanged);
    unawaited(_notKept.cancel());
    _choice.dispose();
    super.dispose();
  }

  /// Shows the change; once the choice is settled, removes this screen's
  /// own route, not whatever is on top (e.g. a dialog).
  void _onChoiceChanged() {
    if (_choice.theirs != null) {
      setState(() {});
    } else if (!_closed && mounted) {
      _closed = true;
      if (ModalRoute.of(context) case final route?) {
        Navigator.removeRoute(context, route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theirs = _choice.theirs;
    final session = widget.controller.session;
    final file = session.file;
    return Scaffold(
      appBar: compareAppBar(
        folder: file.folder,
        file: session.path,
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
                content: EditorText(_choice.mine),
                keepLabel: 'Keep this',
                keptMessage:
                    'Your edits replace the current version. $bothBackedUp',
              ),
              // This device's edits are the base: their own lines green.
              base: VersionSide.other,
              enabled: _choice.canPick,
              // This build's version: the one shown when the user taps.
              onKeep: (side) => _choice.pick(switch (side) {
                VersionSide.current => PickChoice.theirs,
                VersionSide.other => PickChoice.mine,
              }, theirs),
              onMerge: _choice.merges
                  ? () => _choice.pick(PickChoice.merged, theirs)
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
