import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import 'file_controller.dart';

/// The choice between the open file's edits and the version from
/// elsewhere, for the compare screen: what shows, whether both can be
/// merged (asked once per version from elsewhere), and the pick under
/// way. Tells its listeners of every change; [notKept] when a pick
/// changed nothing.
class ChangedElsewhereController extends ChangeNotifier {
  ChangedElsewhereController(this._file) {
    _file.addListener(_onFileChanged);
    _notices = _session.fileNotices.listen((notice) {
      if (notice is! PickNotKept) return;
      _picking = null;
      _notKept.add(null);
      notifyListeners();
    });
    _askMerges();
  }

  final FileController _file;
  late final StreamSubscription<FileEvent> _notices;
  final _notKept = StreamController<void>.broadcast();
  var _disposed = false;

  FileSession get _session => _file.session;

  /// The version a pick was sent against, while it is carried out.
  Seen<ReadVersion>? _picking;

  /// Whether the edits and a version from elsewhere merge, as last asked.
  ({ReadVersion version, bool merges})? _merging;

  /// The version from elsewhere, while the choice is open; `null` once
  /// it was settled, whoever settled it.
  Seen<ReadVersion>? get theirs => switch (_session.status) {
    ChangedElsewhere(:final theirs) => theirs,
    _ => null,
  };

  /// The edits as they show.
  String get mine => _session.text;

  /// Whether the user can pick now: no pick is under way.
  bool get canPick => _picking == null;

  /// Whether the edits and [theirs] can be picked merged, as far as known.
  bool get merges => switch ((_merging, theirs)) {
    ((:final version, :final merges), final theirs?)
        when version == theirs.version =>
      merges,
    _ => false,
  };

  /// Fires when a pick changed nothing, so the user picks again.
  Stream<void> get notKept => _notKept.stream;

  /// Keeps [choice] against [seen], the version shown when the user
  /// tapped; only while the choice is still open: it may have been
  /// settled while the user confirmed.
  void pick(PickChoice choice, Seen<ReadVersion> seen) {
    if (theirs == null) return;
    _picking = seen;
    notifyListeners();
    _session.pick(choice, theirs: seen, rev: _session.rev);
  }

  void _onFileChanged() {
    // A newer version from elsewhere: the pick against the old one
    // changes nothing, so the user picks again.
    if (theirs case final theirs?
        when _picking != null && _picking?.version != theirs.version) {
      _picking = null;
    }
    _askMerges();
    notifyListeners();
  }

  /// Asks whether the edits and the version shown merge, once per
  /// version; an answer for an older version is dropped.
  void _askMerges() {
    final shown = theirs;
    if (shown == null || _merging?.version == shown.version) return;
    _merging = (version: shown.version, merges: false);
    unawaited(
      _session.mergesWith(shown).then((merges) {
        if (_disposed || _merging?.version != shown.version) return;
        _merging = (version: shown.version, merges: merges);
        notifyListeners();
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _file.removeListener(_onFileChanged);
    unawaited(_notices.cancel());
    unawaited(_notKept.close());
    super.dispose();
  }
}
