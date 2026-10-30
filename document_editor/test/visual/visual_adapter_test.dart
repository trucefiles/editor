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
  _Visual(String text)
    : gate = EditorGate(
        md.editorOwner(
          md.MarkdownStart.read(text),
          version: const Version(1),
          startTimer: ManualTimers().start,
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

    final look = lookOf(visual.document.first) as TextLook;
    expect(look.frames.whereType<ItemFrame>().single.checked, isTrue);
  });
}
