import 'dart:async';

import 'package:flutter/material.dart';
import 'package:follow_the_leader/follow_the_leader.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

import '../document_metrics.dart';
import '../editor_gate.dart';
import '../library/editing_menu.dart';
import '../library/editor_look.dart';
import '../library/link_tap_handler.dart';
import '../library/own_clipboard.dart';
import '../library/touch_controls.dart';
import '../ui/document_image.dart';
import '../ui/empty_document_hint.dart';
import 'library/divider_tap_handler.dart';
import 'library/ime_batches.dart';
import 'library/visual_adapter.dart';
import 'library/visual_keys.dart';
import 'row_looks.dart';
import 'ui/block_builder.dart';
import 'ui/format_toolbar.dart';
import 'ui/line_drop_zone.dart';
import 'ui/link_dialog.dart';
import 'ui/link_popup.dart';
import 'ui/row_builder.dart';
import 'ui/visual_look.dart';
import 'visual_actions.dart';

/// Visual edit of the document behind [gate]: its rows, as they read,
/// and the toolbar. Lists at the top level get Add item buttons at
/// [addItems]. A link asked for in [notices] is asked of the user; with
/// the caret in a link, a popup at it offers to open, edit or remove it;
/// links open with [onLink] (a tap opens one only with Ctrl held, see
/// [editingTapOpens]); images show as [images] finds them.
class VisualEditView extends StatefulWidget {
  const VisualEditView(
    this.gate, {
    required this.notices,
    required this.addItems,
    required this.onLink,
    required this.images,
    this.autofocus = false,
    super.key,
  });

  final EditorGate gate;
  final Stream<md.EditorEvent> notices;
  final AddItemPlace? addItems;
  final void Function(String url) onLink;
  final DocumentImages images;

  /// Puts the caret into the document right away, e.g. a new one.
  final bool autofocus;

  @override
  State<VisualEditView> createState() => _VisualEditViewState();
}

class _VisualEditViewState extends State<VisualEditView> {
  final _focus = FocusNode();
  late final _adapter = VisualAdapter(widget.gate, addItems: widget.addItems);
  final _layout = GlobalKey();
  late final _operations = MenuOperations(
    _adapter.editor,
    _adapter.paste,
    layout: _layout,
    copy: _adapter.ownCopy,
  );
  late final _actions = VisualActions(
    widget.gate,
    onFold: (item) => _adapter.folded = item,
    onCaretPlaced: _focus.requestFocus,
  );
  late final StreamSubscription<md.EditorEvent> _notices;

  /// Where the caret is, for the link popup to follow.
  final _selectionLinks = SelectionLayerLinks();
  final _linkPopup = OverlayPortalController()..show();

  /// The look in the current theme and metrics, with the document's
  /// images. Kept between builds: the library lays the whole document out
  /// anew for each new stylesheet.
  EditorLook? _look;
  (ThemeData, DocumentMetrics, DocumentImages)? _lookFor;

  @override
  void initState() {
    super.initState();
    _notices = widget.notices.listen((notice) {
      if (notice case final md.AskLink ask) unawaited(_askLink(ask));
    });
    widget.gate.addListener(_keyboardFollowsCaret);
  }

  /// Without a caret (e.g. after a control), the editor gives up the
  /// keyboard: nothing to type at.
  void _keyboardFollowsCaret() {
    if (!_actions.hasCaret && _focus.hasFocus) _focus.unfocus();
  }

  @override
  void didUpdateWidget(VisualEditView old) {
    super.didUpdateWidget(old);
    _adapter.addItems = widget.addItems;
    _updateLook();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateLook();
  }

  /// Builds the look again once what it shows by changed.
  void _updateLook() {
    final key = (Theme.of(context), DocumentMetrics.of(context), widget.images);
    if (key == _lookFor) return;
    _lookFor = key;
    _look = visualLook(key.$1, metrics: key.$2, images: key.$3);
  }

  @override
  void dispose() {
    unawaited(_notices.cancel());
    widget.gate.removeListener(_keyboardFollowsCaret);
    _adapter.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Asks for the link [ask] says; the state it was asked on decides, so
  /// a change meanwhile drops the answer, as does leaving Visual edit.
  Future<void> _askLink(md.AskLink ask) async {
    final revision = widget.gate.state.revision;
    final answer = await askLink(
      context,
      text: ask.text,
      url: ask.url,
      removable: ask.removable,
    );
    if (!mounted) return;
    switch (answer) {
      case LinkSet(:final text, :final url):
        _actions.setLink(ask.range, text, url, revision: revision);
      case LinkRemoved():
        _actions.removeLink(ask.range, revision: revision);
      case LinkOpened():
        if (ask.url case final url?) widget.onLink(url);
      case null:
        break;
    }
    _focus.requestFocus();
  }

  /// The popup at the link the caret is in, if any, below the caret's
  /// line (above it where there is no room), clear of a touch handle.
  Widget _linkPopupAtCaret(BuildContext context) => ListenableBuilder(
    listenable: widget.gate,
    builder: (context, _) => switch (_actions.caretLink) {
      (:final range, :final url, :final removable, text: _) =>
        Follower.withAligner(
          link: _selectionLinks.caretLink,
          aligner: PreferredPositionAligner.bottom(
            gap: DocumentMetrics.of(context).touch ? 28 : 4,
          ),
          boundary: const KeyboardFollowerBoundary(),
          child: LinkPopup(
            url,
            onOpen: () => widget.onLink(url),
            onEdit: () => _actions.press(md.EditKey.link),
            onRemove: removable
                ? () => _actions.removeLink(
                    range,
                    revision: widget.gate.state.revision,
                  )
                : null,
          ),
        ),
      null => const SizedBox.shrink(),
    },
  );

  /// A tap on a divider puts the caret right after it, with the keyboard
  /// here as for text.
  bool _caretAfterDividerAt(DocumentPosition position) {
    final placed = _adapter.caretAfterDividerAt(position);
    if (placed) _focus.requestFocus();
    return placed;
  }

  @override
  Widget build(BuildContext context) {
    final look = _look!;
    final metrics = DocumentMetrics.of(context);
    final editor = SuperEditor(
      editor: _adapter.editor,
      documentLayoutKey: _layout,
      focusNode: _focus,
      selectionLayerLinks: _selectionLinks,
      autofocus: widget.autofocus,
      stylesheet: look.stylesheet,
      selectionStyle: look.selection,
      documentOverlayBuilders: look.overlays,
      imeOverrides: ImeBatchFix(),
      componentBuilders: [RowBuilder(_actions), BlockBuilder(_actions)],
      keyboardActions: visualKeyboardActions(_adapter),
      contentTapDelegateFactories: [
        (_) => DividerTapHandler(_caretAfterDividerAt),
        (_) => LinkTapHandler(
          linkAt: _adapter.linkAt,
          onLink: widget.onLink,
          opens: editingTapOpens,
        ),
      ],
    );
    return OverlayPortal(
      controller: _linkPopup,
      overlayChildBuilder: _linkPopupAtCaret,
      child: ListenableBuilder(
        listenable: widget.gate,
        builder: (context, editor) => Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  TouchControls(
                    color: look.handleColor,
                    operations: _operations,
                    child: EditingMenu(
                      operations: _operations,
                      child: LineDropZone(
                        step: metrics.levelIndent,
                        goesNextTo: _actions.goesNextTo,
                        onLift: (drag) => _actions.dragStarted(drag.item),
                        onDrop:
                            (
                              drag, {
                              required target,
                              required below,
                              required levels,
                            }) => _actions.drop(
                              drag.item,
                              target: target,
                              below: below,
                              levels: levels,
                            ),
                        onSettled: _actions.dragEnded,
                        child: editor!,
                      ),
                    ),
                  ),
                  EmptyDocumentHint(
                    empty: _isEmpty,
                    padding: look.firstLinePadding,
                  ),
                ],
              ),
            ),
            FormatToolbar(_actions, onDone: _focus.requestFocus),
          ],
        ),
        child: editor,
      ),
    );
  }

  bool get _isEmpty => switch (widget.gate.state.content) {
    md.FormattedContent(:final view) => view.doc.isEmpty,
    md.MarkdownContent() => false,
  };
}
