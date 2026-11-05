import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_markdown/truce_markdown.dart';

/// The one way into an open document's editor owner. Holds box taps for a
/// short wait, so quick taps move together and a mistap can be undone by
/// a second tap; any other user input first sends the waiting ones.
/// Listeners hear once after each call, however many inputs it sent, and
/// whenever the owner's state changes on its own (a save timer).
final class EditorGate extends ChangeNotifier {
  EditorGate(
    this._owner, {
    this.checkDelay = const Duration(milliseconds: 700),
  }) {
    _changes = _owner.changes.listen((_) {
      if (_depth > 0) return;
      _fromUser = false;
      notifyListeners();
    });
  }

  final EditorOwner _owner;
  late final StreamSubscription<EditorState> _changes;

  /// How long box taps wait for more taps.
  final Duration checkDelay;

  /// Box taps waiting, in the order tapped.
  final _waiting = <NodeId>[];

  /// The revision at the first waiting tap: the taps were made on it.
  int _tappedAt = 0;

  Timer? _timer;

  /// Calls running; listeners hear once the outermost ends.
  int _depth = 0;

  EditorState get state => _owner.state;

  /// Whether the owner's latest change came from the user's own input (a
  /// key, typing, a tap, a control), not from elsewhere (the file, a
  /// timer): only then does the view follow the caret.
  bool get fromUser => _fromUser;
  bool _fromUser = false;

  /// Each new state of the owner.
  Stream<EditorState> get changes => _owner.changes;

  /// What the owner's inputs lead to.
  Stream<EditorEvent> get events => _owner.events;

  /// Completes once the owner ended, after [dispose].
  Future<void> get closed => _closed.future;
  final _closed = Completer<void>();

  /// The items whose box tap waits: their boxes show flipped meanwhile.
  Set<NodeId> get waiting => Set.unmodifiable(_waiting);

  /// A user input: sends the waiting taps, then the input [build] makes
  /// from the state as it is then (`null`: none, e.g. a drag start);
  /// whether it made one.
  bool send(EditorInput? Function(EditorState now) build) {
    EditorInput? sent;
    _change(fromUser: true, () {
      _flush();
      sent = build(_owner.state);
      if (sent case final input?) _owner.send(input);
    });
    return sent != null;
  }

  /// A tap on [item]'s box; a second tap on it while it waits takes it
  /// back. The caret goes at once, as after any control.
  void tapBox(NodeId item) => _change(fromUser: true, () {
    _owner.send(const RemoveCaret());
    if (_waiting.isEmpty) _tappedAt = _owner.state.revision;
    if (!_waiting.remove(item)) _waiting.add(item);
    _timer?.cancel();
    _timer = _waiting.isEmpty
        ? null
        : Timer(checkDelay, () => _change(fromUser: true, _flush));
  });

  /// An input not from the user (the file owner's message): the taps go
  /// on waiting.
  void external(EditorInput input) =>
      _change(fromUser: false, () => _owner.send(input));

  void _flush() {
    _timer?.cancel();
    _timer = null;
    if (_waiting.isEmpty) return;
    final items = [..._waiting];
    _waiting.clear();
    _owner.send(ToggleItems(items, revision: _tappedAt));
  }

  void _change(void Function() change, {required bool fromUser}) {
    if (_depth == 0) _fromUser = fromUser;
    _depth++;
    try {
      change();
    } finally {
      _depth--;
    }
    if (_depth == 0) notifyListeners();
  }

  /// Also closes the owner.
  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_changes.cancel());
    _closed.complete(_owner.close());
    super.dispose();
  }
}
