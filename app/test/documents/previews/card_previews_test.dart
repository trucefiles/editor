import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/previews/card_preview.dart';
import 'package:truce_editor/documents/previews/card_previews.dart';

import '../../support.dart';

void main() {
  final folder = folderAt(Directory('/documents'));
  Document doc(String name, {int version = 0}) =>
      listedDocument(folder, name: name, version: version);

  /// The reads asked for, each waiting until the test ends it.
  late Map<Document, Completer<CardPreview>> reads;
  late List<Document> started;

  CardPreviews previews({int capacity = 500, int readsAtOnce = 4}) =>
      CardPreviews(
        (document) {
          started.add(document);
          return (reads[document] = Completer()).future;
        },
        capacity: capacity,
        readsAtOnce: readsAtOnce,
      );

  setUp(() {
    reads = {};
    started = [];
  });

  test('reads a document once and then knows it', () async {
    final cards = previews();
    final a = doc('a.md');

    final read = cards.read(a);
    expect(cards.known(a), isNull);
    reads[a]!.complete(const PreviewUnreadable());

    expect(await read, isA<PreviewUnreadable>());
    expect(cards.known(a), isA<PreviewUnreadable>());
    expect(await cards.read(a), isA<PreviewUnreadable>());
    expect(started, [a]);
  });

  test('reads a new version again', () async {
    final cards = previews();
    unawaited(cards.read(doc('a.md')));
    reads.values.single.complete(const PreviewUnreadable());
    await pumpEventQueue();

    expect(cards.known(doc('a.md', version: 1)), isNull);
  });

  test('reads a few at a time, the one asked last first', () async {
    final cards = previews(readsAtOnce: 1);
    final [a, b, c] = [doc('a.md'), doc('b.md'), doc('c.md')];

    unawaited(cards.read(a));
    unawaited(cards.read(b));
    unawaited(cards.read(c));
    expect(started, [a]);

    reads[a]!.complete(const PreviewUnreadable());
    await pumpEventQueue();

    expect(started, [a, c]);
  });

  test('drops a waiting read whose card went away', () async {
    final cards = previews(readsAtOnce: 1);
    final [a, b] = [doc('a.md'), doc('b.md')];
    unawaited(cards.read(a));
    unawaited(cards.read(b));

    cards.drop(b);
    reads[a]!.complete(const PreviewUnreadable());
    await pumpEventQueue();

    expect(started, [a]);
  });

  test('keeps only the previews used last', () async {
    final cards = previews(capacity: 2);
    final [a, b, c] = [doc('a.md'), doc('b.md'), doc('c.md')];
    for (final document in [a, b]) {
      unawaited(cards.read(document));
      reads[document]!.complete(const PreviewUnreadable());
      await pumpEventQueue();
    }
    cards.known(a);

    unawaited(cards.read(c));
    reads[c]!.complete(const PreviewUnreadable());
    await pumpEventQueue();

    expect(cards.known(a), isNotNull);
    expect(cards.known(b), isNull, reason: 'used least lately');
    expect(cards.known(c), isNotNull);
  });
}
