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

  group('answerOf', () {
    test('gives what is read from the answer', () async {
      final owner = _Replier();
      addTearDown(owner.close);

      final text = await answerOf(
        owner,
        _Question.new,
        read: (_Reply reply) => reply.text,
        orElse: 'ended',
      );

      expect(text, 'replied');
    });

    test('gives the fallback once the owner ended unanswered', () async {
      final owner = _Replier(replies: false);
      final text = answerOf(
        owner,
        _Question.new,
        read: (_Reply reply) => reply.text,
        orElse: 'ended',
      );

      await owner.close();

      expect(await text, 'ended');
    });
  });
}

/// Replies to each question at once, if [replies].
final class _Replier implements Owner<_Question, void, Object?> {
  _Replier({this.replies = true});

  final bool replies;
  final _events = StreamController<Object?>.broadcast(sync: true);

  @override
  void send(_Question input) {
    if (replies) _events.add(_Reply(input.ticket, 'replied'));
  }

  @override
  void get state {}

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Stream<Object?> get events => _events.stream;

  @override
  Future<void> close() => _events.close();
}
