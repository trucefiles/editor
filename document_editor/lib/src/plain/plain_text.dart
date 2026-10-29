import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

import '../lines/edited_text.dart';

/// The text a plain text document's line editor edits: its editor
/// owner's. Listeners hear of each new state of the owner, until it
/// ends.
final class PlainText implements EditedText {
  PlainText(this._owner);

  final PlainOwner _owner;
  final _listening = <VoidCallback, StreamSubscription<PlainState>>{};

  @override
  ShownText get shown => (text: _owner.state.text, caret: _owner.state.caret);

  @override
  void edit(String text, {required bool pasted}) => _owner.send(
    TextEdited(text, revision: _owner.state.revision, pasted: pasted),
  );

  @override
  void caretMoved() => _owner.send(const CaretMoved());

  @override
  void addListener(VoidCallback listener) =>
      _listening[listener] ??= _owner.changes.listen((_) => listener());

  @override
  void removeListener(VoidCallback listener) =>
      unawaited(_listening.remove(listener)?.cancel());
}
