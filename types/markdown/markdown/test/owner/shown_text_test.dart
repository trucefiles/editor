import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart' show Ticket;
import 'package:truce_folders/truce_folders.dart' show SecureReason;
import 'package:truce_markdown/truce_markdown.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import 'editor_run.dart';

void main() {
  test('tells the text that shows, printed as it would be sent, and sends, '
      'keeps or times nothing', () {
    final run = EditorRun('# Shopping\n- milk\n')..caret(1, 0);
    run.type('fresh ');
    final before = run.state;
    final ticket = Ticket();

    final outputs = run.owner.send(AskShownText(ticket));

    expect(outputs, [
      isA<ShownTextAnswer>()
          .having((answer) => answer.ticket, 'ticket', same(ticket))
          .having(
            (answer) => answer.text,
            'text',
            '# Shopping\n- fresh milk\n',
          ),
    ]);
    expect(run.state, same(before));
    expect(run.state.status.unsent, isTrue);

    run.request(SecureEditor(Ticket(), SecureReason.close));
    expect(run.sent, (outputs.single! as ShownTextAnswer).text);
  });

  test('in Markdown edit, tells the text as it is', () {
    final run = EditorRun('# Shopping\n', mode: EditMode.markdown)
      ..editText('# Shopping\nmilk\n');

    final outputs = run.owner.send(AskShownText(Ticket()));

    expect((outputs.single! as ShownTextAnswer).text, '# Shopping\nmilk\n');
  });
}
