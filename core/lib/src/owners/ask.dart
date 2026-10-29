import 'dart:async';

import 'owner.dart';

/// Names one question to an owner; its answer carries it back. Opaque:
/// only compared by identity.
final class Ticket {
  Ticket();
}

/// An input that asks a question, answered later by an [Answering] event.
abstract interface class Asking {
  Ticket get ticket;
}

/// An event that answers the input that carried [ticket].
abstract interface class Answering {
  Ticket get ticket;
}

/// Sends the question [asking] makes with a new ticket through [send],
/// and completes with the [Answer] carrying it back on [events]; `null`
/// if [events] ends first, so no question waits forever. The question may
/// go into one owner and be answered by another.
Future<Answer?> ask<In, Answer extends Answering>(
  void Function(In input) send,
  Stream<Object?> events,
  In Function(Ticket ticket) asking,
) {
  final ticket = Ticket();
  final answer = Completer<Answer?>();
  late final StreamSubscription<Object?> listening;
  listening = events.listen(
    (event) {
      if (event is Answer && identical(event.ticket, ticket)) {
        answer.complete(event);
        unawaited(listening.cancel());
      }
    },
    onDone: () {
      if (!answer.isCompleted) answer.complete(null);
    },
  );
  send(asking(ticket));
  return answer.future;
}

/// Asks [owner] the question [asking] makes (see [ask]), and gives what
/// [read] takes from its answer; [orElse] if the owner ends first.
Future<R> answerOf<In, A extends Answering, R>(
  Owner<In, Object?, Object?> owner,
  In Function(Ticket ticket) asking, {
  required R Function(A answer) read,
  required R orElse,
}) async => switch (await ask<In, A>(owner.send, owner.events, asking)) {
  final answer? => read(answer),
  null => orElse,
};
