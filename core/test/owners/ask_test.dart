import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

final class _Question implements Asking {
  const _Question(this.ticket);

  @override
  final Ticket ticket;
}

final class _Reply implements Answering {
  const _Reply(this.ticket, this.text);

  @override
  final Ticket ticket;
  final String text;
}

void main() {
  test('completes with the answer that carries its ticket back', () async {
    final events = StreamController<Object?>.broadcast(sync: true);
    final answer = ask<_Question, _Reply>(
      (question) {
        events
          ..add(_Reply(Ticket(), 'not mine'))
          ..add(_Reply(question.ticket, 'mine'));
      },
      events.stream,
      _Question.new,
    );
    expect((await answer)?.text, 'mine');
  });

  test('the answer may come later, from another owner', () async {
    final asked = <_Question>[];
    final answers = StreamController<Object?>.broadcast();
    final answer = ask<_Question, _Reply>(
      asked.add,
      answers.stream,
      _Question.new,
    );
    answers.add(_Reply(asked.single.ticket, 'later'));
    expect((await answer)?.text, 'later');
  });

  test('completes with null once the events end unanswered', () async {
    final events = StreamController<Object?>.broadcast();
    final answer = ask<_Question, _Reply>((_) {}, events.stream, _Question.new);
    await events.close();
    expect(await answer, isNull);
  });
}
