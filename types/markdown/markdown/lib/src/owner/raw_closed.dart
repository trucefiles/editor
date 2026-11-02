import '../edit/change.dart';
import '../edit/commands/command.dart';
import '../edit/selection.dart';
import 'editor_contract.dart';

/// What [shown] holds once its open raw block, if one is, takes the text
/// typed in it, [selection] where it stays; without one, what the raw
/// text reads as selected, or, with no raw block open, the selection as
/// it is.
Edited rawClosed(FormattedContent shown, Selection? selection) =>
    switch (shown.raw) {
      final raw? => run(shown.view, CloseRaw(raw.block, raw.text, selection)),
      null => (doc: shown.view.doc, selection: selection ?? shown.selection),
    };
