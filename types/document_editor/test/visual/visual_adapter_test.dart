import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart'
    show Edited, SecureEditor, SecureReason, Ticket, ToFile, Version;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;
import 'package:truce_test_support/truce_test_support.dart' show ManualTimers;

/// A Visual edit adapter on an editor owner of [text].
final class _Visual {
  _Visual(String text, {md.EditorOwner Function(md.EditorOwner)? owner})
    : gate = EditorGate(
        (owner ?? (owner) => owner)(
          md.editorOwner(
            md.MarkdownStart.read(text),
            version: const Version(1),
            startTimer: ManualTimers().start,
          ),
        ),
      ) {
    gate.events.listen(outputs.add);
    adapter = VisualAdapter(gate);
  }

  final EditorGate gate;
  late final VisualAdapter adapter;
  final outputs = <md.EditorEvent>[];

  Editor get editor => adapter.editor;
  Document get document => adapter.document;

  /// The text of each node.
  List<String> get texts => [
    for (final node in document)
      node is TextNode ? node.text.toPlainText() : '[${node.runtimeType}]',
  ];

  List<String> get ids => [for (final node in document) node.id];

  DocumentSelection? get selection => adapter.composer.selection;

  /// The text the owner sends once secured.
  String secured() {
    gate.send((_) => md.Request(SecureEditor(Ticket(), SecureReason.close)));
    return [
      for (final output in outputs)
        if (output case md.Notice(notice: ToFile(input: final Edited edited)))
          edited.text,
    ].last;
  }

  DocumentPosition at(int node, int offset) => DocumentPosition(
    nodeId: document.getNodeAt(node)!.id,
    nodePosition: TextNodePosition(offset: offset),
  );

  void caret(int node, int offset) => editor.execute([
    ChangeSelectionRequest(
      DocumentSelection.collapsed(position: at(node, offset)),
      SelectionChangeType.placeCaret,
      SelectionReason.userInteraction,
    ),
  ]);
}

/// An owner that answers Enter with an Add item on the first list: a new
/// row further down, while the caret's row keeps its look.
final class _EnterAddsItem implements md.EditorOwner {
  _EnterAddsItem(this._owner);

  final md.EditorOwner _owner;

  @override
  void send(md.EditorInput input) => _owner.send(switch (input) {
    md.Pressed(key: md.EditKey.enter, :final revision) => md.Run(
      md.AddItem(_firstList),
      revision: revision,
    ),
    _ => input,
  });

  md.NodeId get _firstList => (_owner.state.content as md.FormattedContent)
      .view
      .doc
      .root
      .children
      .whereType<md.ListNode>()
      .first
      .id;

  @override
  md.EditorState get state => _owner.state;

  @override
  Stream<md.EditorState> get changes => _owner.changes;

  @override
  Stream<md.EditorEvent> get events => _owner.events;

  @override
  Future<void> close() => _owner.close();
}

void main() {
  test('shows one node per row', () {
    final visual = _Visual('# Title\n\n- [ ] a\n- [x] b\n\n---\n\nend');

    expect(visual.texts, ['Title', 'a', 'b', '[LookBlockNode]', 'end']);
  });

  test('typed text goes to the owner, which the document then shows', () {
    final visual = _Visual('ab');
    visual.caret(0, 1);

    visual.editor.execute([
      InsertTextRequest(
        documentPosition: visual.at(0, 1),
        textToInsert: 'x',
        attributions: const {},
      ),
    ]);

    expect(visual.texts, ['axb']);
    expect(
      visual.selection?.extent.nodePosition,
      const TextNodePosition(offset: 2),
    );
    expect(visual.secured(), 'axb');
  });

  test('typing patches only the rows whose looks changed: the other nodes '
      'stay as they are', () {
    final visual = _Visual('- [ ] a\n- [ ] b\n- [ ] c\n\nd');
    visual.caret(1, 1);
    final nodes = visual.document.toList();

    visual.editor.execute([
      InsertTextRequest(
        documentPosition: visual.at(1, 1),
        textToInsert: 'x',
        attributions: const {},
      ),
    ]);

    final now = visual.document.toList();
    expect(visual.texts, ['a', 'bx', 'c', 'd']);
    for (final index in [0, 2, 3]) {
      expect(identical(now[index], nodes[index]), isTrue, reason: '$index');
    }
  });

  for (final atEnd in [false, true]) {
    test('Enter ${atEnd ? 'at the end of' : 'inside'} a row patches both '
        'rows of the split, the other nodes stay as they are', () {
      final visual = _Visual(
        [for (var item = 0; item < 20; item++) '- [ ] item $item'].join('\n'),
      );
      final offset = atEnd ? 'item 10'.length : 2;
      visual.caret(10, offset);
      final nodes = visual.document.toList();

      visual.editor.execute([
        InsertNewlineAtCaretRequest(Editor.createNodeId()),
      ]);

      final now = visual.document.toList();
      expect(now, hasLength(21));
      expect(now[10].id, nodes[10].id);
      expect(visual.selection?.extent.nodeId, now[11].id);
      expect(visual.texts[10], 'item 10'.substring(0, offset));
      for (final index in [...Iterable<int>.generate(10), 12, 20]) {
        final before = nodes[index < 10 ? index : index - 1];
        expect(identical(now[index], before), isTrue, reason: '$index');
      }
    });
  }

  test('Enter on an empty last item, which leaves its list, patches both '
      'rows of the split', () {
    final visual = _Visual('- [ ] a\n- [ ] b\n- [ ] ');
    visual.caret(2, 0);
    final nodes = visual.document.toList();

    visual.editor.execute([InsertNewlineAtCaretRequest('new')]);

    final now = visual.document.toList();
    expect(visual.texts, ['a', 'b', '']);
    expect(identical(now.first, nodes.first), isTrue);
    expect(now[1].id, nodes[2].id);
    expect(now[2].id, 'new');
    expect(visual.selection?.extent.nodeId, 'new');
  });

  test('an Enter that keeps the caret\'s row as it was still patches it, '
      'as its node now shows the row above the new caret', () {
    final visual = _Visual('- a\n  - b\n\nc', owner: _EnterAddsItem.new);
    visual.caret(0, 1);
    final nodes = visual.document.toList();

    visual.editor.execute([InsertNewlineAtCaretRequest('new')]);

    final now = visual.document.toList();
    expect(visual.texts, ['a', 'b', '', 'c']);
    expect(now.map((node) => node.id).toSet(), hasLength(4));
    expect(now[1].id, nodes.first.id);
    expect(now[2].id, 'new');
    expect(identical(now.last, nodes.last), isTrue);
    expect([
      for (final node in now) lookOf(node),
    ], md.looksOf(visual.gate.state.content as md.FormattedContent));
  });

  test('a caret the user moves goes to the owner', () {
    final visual = _Visual('ab');

    visual.caret(0, 2);

    expect(
      (visual.gate.state.content as md.FormattedContent).selection,
      isA<md.TextSelection>().having(
        (selection) => selection.extent.offset,
        'offset',
        2,
      ),
    );
  });

  test('Enter splits: the top keeps its node, the caret goes to the new '
      'one the library named', () {
    final visual = _Visual('- abc');
    final top = visual.ids.single;
    visual.caret(0, 1);

    visual.editor.execute([InsertNewlineAtCaretRequest('new')]);

    expect(visual.texts, ['a', 'bc']);
    expect(visual.ids, [top, 'new']);
    expect(visual.selection?.extent.nodeId, 'new');
    expect(visual.secured(), '- a\n- bc');
  });

  test('Backspace at a start joins with the row above', () {
    final visual = _Visual('a\n\nb');
    visual.caret(1, 0);

    visual.editor.execute([
      DeleteUpstreamAtBeginningOfNodeRequest(visual.document.getNodeAt(1)!),
    ]);

    expect(visual.texts, ['ab']);
  });

  test('pasted lines in an item become items, as with Enter', () {
    final visual = _Visual('- [ ] ab');
    visual.caret(0, 1);

    visual.adapter.paste('x\ny');

    expect(visual.texts, ['ax', 'yb']);
    expect(visual.secured(), '- [ ] ax\n- [ ] yb');
  });

  group('on a selected divider, as on one selected character', () {
    /// The divider selected as a range, as a double click selects it.
    _Visual selected() {
      final visual = _Visual('a\n\n---\n\nb');
      final divider = visual.document.getNodeAt(1)!.id;
      visual.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection(
            base: DocumentPosition(
              nodeId: divider,
              nodePosition: const UpstreamDownstreamNodePosition.upstream(),
            ),
            extent: DocumentPosition(
              nodeId: divider,
              nodePosition: const UpstreamDownstreamNodePosition.downstream(),
            ),
          ),
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
      ]);
      return visual;
    }

    test('a typed character takes its place', () {
      final visual = selected();
      visual.editor.execute([InsertCharacterAtCaretRequest(character: 'x')]);
      expect(visual.texts, ['a', 'x', 'b']);
    });

    test('pasted lines take its place', () {
      final visual = selected();
      visual.adapter.paste('x\ny');
      expect(visual.texts, ['a', 'x', 'y', 'b']);
    });

    test('a deletion removes it', () {
      final visual = selected();
      visual.editor.execute([DeleteSelectionRequest(TextAffinity.upstream)]);
      expect(visual.texts, ['a', 'b']);
    });
  });

  group('right after a tapped divider, as after one character', () {
    _Visual tapped() {
      final visual = _Visual('a\n\n---\n\nb');
      expect(
        visual.adapter.caretAfterDividerAt(
          DocumentPosition(
            nodeId: visual.document.getNodeAt(1)!.id,
            nodePosition: const UpstreamDownstreamNodePosition.upstream(),
          ),
        ),
        isTrue,
      );
      return visual;
    }

    test('the library has its caret at the divider\'s end', () {
      final visual = tapped();
      expect(
        visual.selection,
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: visual.document.getNodeAt(1)!.id,
            nodePosition: const UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
      );
    });

    test('a typed character starts a new line after it', () {
      final visual = tapped();
      visual.editor.execute([InsertCharacterAtCaretRequest(character: 'x')]);
      expect(visual.secured(), 'a\n\n---\n\nx\n\nb');
    });

    test('pasted lines go after it', () {
      final visual = tapped();
      visual.adapter.paste('x\ny');
      expect(visual.secured(), 'a\n\n---\n\nx\n\ny\n\nb');
    });

    test('Backspace removes it', () {
      final visual = tapped();
      visual.editor.execute([const DeleteUpstreamRequest()]);
      expect(visual.secured(), 'a\n\nb');
    });
  });

  test('pasted Markdown marks stay text', () {
    final visual = _Visual('ab');
    visual.caret(0, 1);

    visual.adapter.paste('**x**');

    expect(visual.texts, ['a**x**b']);
    expect(visual.secured(), r'a\*\*x\*\*b');
  });

  group('requests', () {
    /// The requests Visual edit refused, by the message it prints.
    final refused = <String>[];
    setUp(() {
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => refused.add(message ?? '');
      addTearDown(() {
        debugPrint = print;
        refused.clear();
      });
    });

    /// A Visual edit of 'abc' with b selected, after [request].
    _Visual after(EditRequest Function(_Visual visual) request) {
      final visual = _Visual('abc');
      visual.editor.execute([
        ChangeSelectionRequest(
          DocumentSelection(base: visual.at(0, 1), extent: visual.at(0, 2)),
          SelectionChangeType.expandSelection,
          SelectionReason.userInteraction,
        ),
      ]);
      visual.editor.execute([request(visual)]);
      return visual;
    }

    String first(_Visual visual) => visual.document.first.id;

    final ownerInputs = <String, EditRequest Function(_Visual)>{
      'InsertText': (visual) => InsertTextRequest(
        documentPosition: visual.at(0, 1),
        textToInsert: 'x',
        attributions: const {},
      ),
      'InsertPlainTextAtCaret': (_) => const InsertPlainTextAtCaretRequest('x'),
      'InsertCharacterAtCaret': (_) =>
          InsertCharacterAtCaretRequest(character: 'x'),
      'InsertStyledTextAtCaret': (_) =>
          InsertStyledTextAtCaretRequest(AttributedText('x')),
      'DeleteSelection': (_) => DeleteSelectionRequest(TextAffinity.upstream),
      'DeleteContent': (visual) => DeleteContentRequest(
        documentRange: DocumentRange(
          start: visual.at(0, 1),
          end: visual.at(0, 2),
        ),
      ),
      'DeleteUpstream': (_) => const DeleteUpstreamRequest(),
      'DeleteUpstreamCharacter': (_) => const DeleteUpstreamCharacterRequest(),
      'DeleteUpstreamAtBeginningOfNode': (visual) =>
          DeleteUpstreamAtBeginningOfNodeRequest(visual.document.first),
      'DeleteDownstream': (_) => const DeleteDownstreamRequest(),
      'DeleteDownstreamCharacter': (_) =>
          const DeleteDownstreamCharacterRequest(),
      'CombineParagraphs': (visual) => CombineParagraphsRequest(
        firstNodeId: first(visual),
        secondNodeId: 'next',
      ),
      'InsertNewlineAtCaret': (_) => InsertNewlineAtCaretRequest(),
      'InsertSoftNewlineAtCaret': (_) =>
          const InsertSoftNewlineAtCaretRequest(),
      'Paste': (_) => const PasteRequest('x'),
    };

    for (final MapEntry(key: name, value: request) in ownerInputs.entries) {
      test('$name goes to the owner', () {
        final visual = after(request);

        expect(refused, isEmpty);
        expect(visual.texts, isNot(['abc']));
      });
    }

    final librarys = <String, EditRequest Function(_Visual)>{
      'ChangeSelection': (visual) => ChangeSelectionRequest(
        DocumentSelection.collapsed(position: visual.at(0, 3)),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
      'ClearSelection': (_) => const ClearSelectionRequest(),
      'ChangeComposingRegion': (visual) => ChangeComposingRegionRequest(
        DocumentRange(start: visual.at(0, 0), end: visual.at(0, 1)),
      ),
      'ClearComposingRegion': (_) => const ClearComposingRegionRequest(),
      'ChangeInteractionMode': (_) =>
          const ChangeInteractionModeRequest(isInteractionModeDesired: true),
      'RemoveComposerPreferenceStyles': (_) =>
          RemoveComposerPreferenceStylesRequest(const {}),
      'ChangeSingleColumnLayoutComponentStyles': (visual) =>
          ChangeSingleColumnLayoutComponentStylesRequest(
            nodeId: first(visual),
            styles: SingleColumnLayoutComponentStyles(),
          ),
    };

    for (final MapEntry(key: name, value: request) in librarys.entries) {
      test('$name goes to the library and leaves the text', () {
        final visual = after(request);

        expect(refused, isEmpty);
        expect(visual.texts, ['abc']);
      });
    }

    final refusals = <String, EditRequest Function(_Visual)>{
      'DeleteNode': (visual) => DeleteNodeRequest(nodeId: first(visual)),
      'MoveNode': (visual) =>
          MoveNodeRequest(nodeId: first(visual), newIndex: 0),
      'ReplaceNode': (visual) => ReplaceNodeRequest(
        existingNodeId: first(visual),
        newNode: ParagraphNode(id: 'new', text: AttributedText('x')),
      ),
      'ReplaceNodeWithEmptyParagraphWithCaret': (visual) =>
          ReplaceNodeWithEmptyParagraphWithCaretRequest(nodeId: first(visual)),
      'InsertNodeAtIndex': (_) => InsertNodeAtIndexRequest(
        nodeIndex: 0,
        newNode: ParagraphNode(id: 'new', text: AttributedText('x')),
      ),
      'InsertAttributedText': (visual) =>
          InsertAttributedTextRequest(visual.at(0, 1), AttributedText('x')),
      'InsertPlainTextAtEndOfDocument': (_) =>
          InsertPlainTextAtEndOfDocumentRequest('x'),
    };

    for (final MapEntry(key: name, value: request) in refusals.entries) {
      test('$name is refused', () {
        final visual = after(request);

        expect(refused, ['Visual edit refused ${name}Request']);
        expect(visual.texts, ['abc']);
      });
    }

    test('the library has no other requests', () {
      // A library update that changes its requests fails here: check the
      // lists above still hold. Any request that is neither an owner input
      // nor the library's own is refused.
      expect(defaultRequestHandlers, hasLength(68));
    });
  });

  test('a selection from outside into an open raw block closes it', () {
    final visual = _Visual('a\n\n| x |\n|---|\n| 1 |');
    md.RawRegion? raw() =>
        (visual.gate.state.content as md.FormattedContent).raw;
    final table = (visual.gate.state.content as md.FormattedContent)
        .view
        .doc
        .root
        .children
        .whereType<md.TableNode>()
        .single;
    visual.gate.send(
      (now) => md.OpenRawBlock(table.id, atEnd: false, revision: now.revision),
    );
    expect(raw(), isNotNull);

    visual.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(base: visual.at(0, 0), extent: visual.at(1, 2)),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);

    expect(raw(), isNull);
  });

  test('a waiting box tap shows checked at once', () {
    final visual = _Visual('- [ ] a');
    final item =
        ((visual.gate.state.content as md.FormattedContent)
                    .view
                    .doc
                    .root
                    .children
                    .single
                as md.ListNode)
            .items
            .single;

    visual.gate.tapBox(item.id);

    final look = lookOf(visual.document.first) as md.TextLook;
    expect(look.frames.whereType<md.ItemFrame>().single.checked, isTrue);
  });

  test('random edits, taps and controls each leave the document showing '
      'the looks of the owner\'s state', () {
    final random = Random(11);
    final visual = _Visual(
      '# Title\n\n- [ ] a\n  - [ ] a1\n- [ ] b\n- [x] done\n\n> q1\n>\n'
      '> q2\n\n| x |\n|---|\n| 1 |\n\n---\n\n1. n\n2. m\n\nend',
    );
    AddItemPlace? addItems;
    md.NodeId? folded;
    md.FormattedContent shown() =>
        visual.gate.state.content as md.FormattedContent;
    List<md.DocBlock> nodes() => md.nodesIn(shown().view.doc.root).toList();
    List<int> textRows() => [
      for (final (index, node) in visual.document.indexed)
        if (node is TextNode) index,
    ];
    T pick<T>(List<T> from) => from[random.nextInt(from.length)];
    int offsetIn(int row) => random.nextInt(
      (visual.document.getNodeAt(row)! as TextNode).text.length + 1,
    );
    String word() => pick(['x', 'two words', '', 'y\nz']);

    for (var round = 0; round < 300; round++) {
      final rows = textRows();
      final row = pick(rows);
      switch (random.nextInt(10)) {
        case 0:
          final offset = offsetIn(row);
          visual
            ..caret(row, offset)
            ..editor.execute([
              InsertTextRequest(
                documentPosition: visual.at(row, offset),
                textToInsert: word(),
                attributions: const {},
              ),
            ]);
        case 1:
          visual
            ..caret(row, offsetIn(row))
            ..editor.execute([InsertNewlineAtCaretRequest()]);
        case 2 when row > 0:
          visual
            ..caret(row, 0)
            ..editor.execute([
              DeleteUpstreamAtBeginningOfNodeRequest(
                visual.document.getNodeAt(row)!,
              ),
            ]);
        case 3:
          // A short range, so the blocks last for the other steps.
          final end = pick(
            rows.where((other) => other >= row && other <= row + 2).toList(),
          );
          visual.editor.execute([
            ChangeSelectionRequest(
              DocumentSelection(
                base: visual.at(row, offsetIn(row)),
                extent: visual.at(end, offsetIn(end)),
              ),
              SelectionChangeType.expandSelection,
              SelectionReason.userInteraction,
            ),
            DeleteSelectionRequest(TextAffinity.downstream),
          ]);
        case 4:
          visual
            ..caret(row, offsetIn(row))
            ..adapter.paste(word());
        case 5:
          final boxes = nodes().whereType<md.ItemNode>().where(
            (item) => item.hasBox,
          );
          if (boxes.isNotEmpty) visual.gate.tapBox(pick(boxes.toList()).id);
        case 6:
          folded = pick([
            null,
            ...nodes().whereType<md.ItemNode>().map((item) => item.id),
          ]);
          visual.adapter.folded = folded;
        case 7:
          addItems = pick([null, ...AddItemPlace.values]);
          visual.adapter.addItems = addItems;
        case 8:
          final tables = nodes().whereType<md.TableNode>();
          if (tables.isNotEmpty && shown().raw == null) {
            visual.gate.send(
              (now) => md.OpenRawBlock(
                tables.first.id,
                atEnd: random.nextBool(),
                revision: now.revision,
              ),
            );
          }
        case 9:
          final raw = visual.document.indexed
              .where((row) => lookOf(row.$2) is md.RawTextLook)
              .firstOrNull;
          if (raw case (final index, _)) {
            final offset = offsetIn(index);
            visual.editor.execute([
              InsertTextRequest(
                documentPosition: visual.at(index, offset),
                textToInsert: word(),
                attributions: const {},
              ),
            ]);
          }
        case _:
          continue;
      }
      expect(
        [for (final node in visual.document) lookOf(node)],
        md.looksOf(
          shown(),
          waiting: visual.gate.waiting,
          addItems: addItems,
          folded: folded,
        ),
        reason: 'round $round',
      );
    }
  });
}
