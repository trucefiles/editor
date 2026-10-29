import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_plain_text/truce_plain_text.dart';
import 'package:truce_test_support/truce_test_support.dart' show ManualTimers;

/// A plain text document's editor owner in memory, as its line editor
/// gets it: records the texts it sends to be kept.
final class _Plain {
  _Plain(String text)
    : owner = plainOwner(
        text,
        version: const Version(1),
        // Never fire: the text is sent as the tests ask.
        startTimer: ManualTimers().start,
      ) {
    owner.events.listen((event) {
      if (event.notice case ToFile(input: Edited(:final text))) {
        edits.add(text);
      }
    });
    // Not awaited: the owner ends after the test's fake time.
    addTearDown(() => unawaited(owner.close()));
  }

  final PlainOwner owner;

  /// Each text sent to be kept, in order.
  final edits = <String>[];

  /// The text as the owner keeps it now, every edit sent.
  String get text {
    owner.send(PlainRequest(SecureEditor(Ticket(), SecureReason.hide)));
    return edits.last;
  }
}

Future<void> _pumpPlain(WidgetTester tester, _Plain plain) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: LineEditView(PlainText(plain.owner), editing: plainLines),
    ),
  ),
);

/// Editing a plain text document.
void main() {
  testWidgets('edits the text as written', (tester) async {
    final plain = _Plain('# not a heading\n- [ ] milk');
    await _pumpPlain(tester, plain);

    await tester.caretIn(lineNodeOf(1), 4);
    await tester.typeImeText('x');
    await tester.pressEnter();
    await tester.typeImeText('y');

    expect(plain.text, '# not a heading\n- [ x\ny] milk');
  });

  testWidgets('every line shows in the same style', (tester) async {
    await _pumpPlain(tester, _Plain('# Title\n\ntext'));

    TextStyle? styleOf(String text) => tester
        .widget<RichText>(find.text(text, findRichText: true).first)
        .text
        .style;
    expect(styleOf('# Title')?.fontSize, styleOf('text')?.fontSize);
  });

  testWidgets('undo takes back typing, the caret at the change', (
    tester,
  ) async {
    final plain = _Plain('ab');
    await _pumpPlain(tester, plain);
    await tester.caretIn(lineNodeOf(0), 2);
    await tester.typeImeText('cd');

    plain.owner.send(const PlainRequest(Undo()));
    await tester.pumpAndSettle();
    await tester.typeImeText('x');

    expect(plain.text, 'abx');
  });

  testWidgets('redo brings the typing back', (tester) async {
    final plain = _Plain('ab');
    await _pumpPlain(tester, plain);
    await tester.caretIn(lineNodeOf(0), 2);
    await tester.typeImeText('cd');

    plain.owner.send(const PlainRequest(Undo()));
    await tester.pumpAndSettle();
    plain.owner.send(const PlainRequest(Redo()));
    await tester.pumpAndSettle();

    expect(plain.owner.state.text, 'abcd');
    expect(find.text('abcd', findRichText: true), findsOne);
  });

  testWidgets('a word typed letter by letter is one undo step', (tester) async {
    final plain = _Plain('a');
    await _pumpPlain(tester, plain);
    await tester.caretIn(lineNodeOf(0), 1);
    await tester.typeImeText(' milk');

    plain.owner.send(const PlainRequest(Undo()));
    await tester.pumpAndSettle();

    expect(plain.text, 'a ');
  });

  testWidgets('typing after a click away and back is a new undo step', (
    tester,
  ) async {
    final plain = _Plain('ab');
    await _pumpPlain(tester, plain);
    await tester.caretIn(lineNodeOf(0), 2);
    await tester.typeImeText('cd');

    await tester.caretIn(lineNodeOf(0), 0);
    await tester.caretIn(lineNodeOf(0), 4);
    await tester.typeImeText('e');
    plain.owner.send(const PlainRequest(Undo()));
    await tester.pumpAndSettle();

    expect(plain.text, 'abcd');
  });

  testWidgets('a paste is an undo step of its own', (tester) async {
    final plain = _Plain('a');
    await _pumpPlain(tester, plain);
    tester.clipboardHolds('bc');
    await tester.caretIn(lineNodeOf(0), 1);
    await tester.typeImeText('x');

    await tester.pressCtlV();
    await tester.pumpAndSettle();
    await tester.typeImeText('y');
    plain.owner.send(const PlainRequest(Undo()));
    await tester.pumpAndSettle();
    expect(plain.owner.state.text, 'axbc');

    plain.owner.send(const PlainRequest(Undo()));
    await tester.pumpAndSettle();
    expect(plain.text, 'ax');
  });

  testWidgets('a paste over a selected word is one undo step', (tester) async {
    final plain = _Plain('buy milk');
    await _pumpPlain(tester, plain);
    tester.clipboardHolds('eggs');
    await tester.selectWordIn(lineNodeOf(0), 5);

    await tester.pressCtlV();
    await tester.pumpAndSettle();
    expect(plain.owner.state.text, 'buy eggs');

    plain.owner.send(const PlainRequest(Undo()));
    await tester.pumpAndSettle();
    expect(plain.text, 'buy milk');
  });

  testWidgets('the touch toolbar pastes as one undo step', (tester) async {
    final plain = _Plain('buy milk');
    await _pumpPlain(tester, plain);
    tester.clipboardHolds('eggs');
    await tester.selectWordIn(lineNodeOf(0), 5);

    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(plain.owner.state.text, 'buy eggs');

    plain.owner.send(const PlainRequest(Undo()));
    await tester.pumpAndSettle();
    expect(plain.text, 'buy milk');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a change from elsewhere shows right away', (tester) async {
    final plain = _Plain('a');
    await _pumpPlain(tester, plain);

    plain.owner.send(
      const PlainRequest(
        FromFile(Replaced('a\nb', version: Version(2), ackRev: 0)),
      ),
    );
    await tester.pumpAndSettle();

    expect(SuperEditorInspector.findDocument()!.nodeCount, 2);
    expect(plain.edits, isEmpty);
  });

  testWidgets('the part shows the text only to read while read only', (
    tester,
  ) async {
    final part = PlainEditorPart((
      text: 'one\ntwo',
      version: const Version(1),
      view: ViewSettings.none,
      readOnly: true,
      isNew: false,
    ));
    addTearDown(() => unawaited(part.editor.close()));
    final view = PlainEditorView(part);
    final host = (
      kept: 'one\ntwo',
      addItems: AddItemPlace.bottom,
      openLink: (Uri _) async {},
      hint: (String _) {},
      images: (String _) => null,
    );
    Future<void> pumpPart() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamBuilder<void>(
            stream: part.changes,
            builder: (_, _) => view.view(host, autofocus: false),
          ),
        ),
      ),
    );
    await pumpPart();

    expect(find.byType(PlainReadView), findsOne);
    expect(find.byType(SuperEditor), findsNothing);
    expect(part.isEditing, isFalse);

    // It shows the editor's text, not the text as last kept.
    part.editor.send(
      const FromFile(Replaced('one\nnew', version: Version(2), ackRev: 0)),
    );
    await tester.pump();
    expect(find.text('one\nnew'), findsOne);

    part.showReadOnly(readOnly: false);
    await tester.pumpAndSettle();

    expect(find.byType(SuperEditor), findsOne);
    expect(part.isEditing, isTrue);
  });
}
