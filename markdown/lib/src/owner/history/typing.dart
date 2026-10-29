import 'package:truce_core/truce_core.dart' show Typing, typingIn;

import '../../edit/commands/text_commands.dart' show ordered;
import '../../edit/keys/key_map.dart';
import '../../edit/selection.dart';
import '../../edit/text_places.dart';
import '../editor_contract.dart';

/// The typing [input] was, which changed what showed from [before] to
/// [after]; `null` for any other edit, which is a step of its own (a
/// paste too).
Typing? typingOf(EditorInput input, EditorState before, EditorState after) =>
    switch ((input, before.content, after.content)) {
      (
        Typed(pasted: true) || EditRaw(pasted: true) || EditText(pasted: true),
        _,
        _,
      ) =>
        null,
      (
        Typed(:final text, :final over),
        FormattedContent(raw: null, :final view),
        FormattedContent(raw: null, selection: TextSelection(:final extent)),
      )
          when !text.contains('\n') &&
              over.base.leaf == over.extent.leaf &&
              extent.leaf == over.extent.leaf =>
        switch (ordered(view, over)) {
          (final from, final to) => Typing(
            from.leaf,
            from: from.offset,
            to: to.offset,
            added: text,
            end: extent.offset,
          ),
        },
      (
        Pressed(key: EditKey.backspace || EditKey.delete),
        FormattedContent(
          raw: null,
          view: final view,
          selection: TextSelection(isCaret: true, extent: final caret),
        ),
        FormattedContent(
          raw: null,
          view: final next,
          selection: TextSelection(isCaret: true, extent: final now),
        ),
      )
          when now.leaf == caret.leaf && next.doc.nodeOf(now.leaf) != null =>
        _deleted(
          now,
          textAt(view.doc, caret.leaf).length -
              textAt(next.doc, now.leaf).length,
        ),
      (
        EditRaw(),
        FormattedContent(raw: final was?),
        FormattedContent(raw: final raw?),
      )
          when raw.block == was.block =>
        typingIn((#raw, raw.block), was.text, raw.text),
      (
        EditText(),
        MarkdownContent(text: final was),
        MarkdownContent(:final text),
      ) =>
        typingIn(#markdown, was, text),
      _ => null,
    };

/// [count] characters deleted at [caret] as typing; `null` where the
/// caret's text lost none (e.g. a divider went), which is a step of its
/// own.
Typing? _deleted(Place caret, int count) => count > 0
    ? Typing(
        caret.leaf,
        from: caret.offset,
        to: caret.offset + count,
        added: '',
        end: caret.offset,
      )
    : null;
