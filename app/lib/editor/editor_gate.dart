import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_markdown/truce_markdown.dart';

/// The one way into an open document's editor owner. Holds box taps for a
/// short wait, so quick taps move together and a mistap can be undone by
/// a second tap; any other user input first sends the waiting ones.
/// Listeners hear once after each call, however many inputs it sent.
final class EditorGate extends ChangeNotifier {
  EditorGate(
    this._owner, {
    this.checkDelay = const Duration(milliseconds: 700),
  });

  final EditorOwner _owner;

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

  /// What the owner's inputs lead to.
  Stream<EditorOutput> get outputs => _owner.outputs;

  /// Whether [item]'s box shows checked: its state, flipped while a tap on
  /// it waits.
  bool showsChecked(ItemNode item) =>
      (item.checked ?? false) != _waiting.contains(item.id);

  /// A user input: sends the waiting taps, then the input [build] makes
  /// from the state as it is then (`null`: none, e.g. a drag start).
  void send(EditorInput? Function(EditorState now) build) => _change(() {
    _flush();
    if (build(_owner.state) case final input?) _owner.send(input);
  });

  /// A tap on [item]'s box; a second tap on it while it waits takes it
  /// back.
  void tapBox(NodeId item) => _change(() {
    if (_waiting.isEmpty) _tappedAt = _owner.state.revision;
    if (!_waiting.remove(item)) _waiting.add(item);
    _timer?.cancel();
    _timer = _waiting.isEmpty
        ? null
        : Timer(checkDelay, () => _change(_flush));
  });

  /// An input not from the user (the file owner's message, a save timer):
  /// the taps go on waiting.
  void external(EditorInput input) => _change(() => _owner.send(input));

  void _flush() {
    _timer?.cancel();
    _timer = null;
    if (_waiting.isEmpty) return;
    final items = [..._waiting];
    _waiting.clear();
    _owner.send(ToggleItems(items, revision: _tappedAt));
  }

  void _change(void Function() change) {
    _depth++;
    try {
      change();
    } finally {
      _depth--;
    }
    if (_depth == 0) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
