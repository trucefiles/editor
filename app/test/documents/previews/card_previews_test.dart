import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../support.dart';

void main() {
  final folder = folderAt(Directory('/documents'));
  Document doc(String name, {int version = 0}) =>
      listedDocument(folder, name: name, version: version);

  final previewed = Previewed(
    DocumentCardSummary(title: 'A', preview: (_) => ''),
  );

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
    reads[a]!.complete(previewed);

    expect(await read, isA<Previewed>());
    expect(cards.known(a), isA<Previewed>());
    expect(await cards.read(a), isA<Previewed>());
    expect(started, [a]);
  });

  test('reads a document again after a read that failed', () async {
    final cards = previews();
    final a = doc('a.md');
    unawaited(cards.read(a));
    reads[a]!.complete(const PreviewUnreadable());
    await pumpEventQueue();

    expect(cards.known(a), isNull);
    unawaited(cards.read(a));
    expect(started, [a, a]);
  });

  test('reads a new version again', () async {
    final cards = previews();
    unawaited(cards.read(doc('a.md')));
    reads.values.single.complete(previewed);
    await pumpEventQueue();

    expect(cards.known(doc('a.md', version: 1)), isNull);
  });

  test('knows the preview last read of a file while its new version is '
      'read, and keeps one preview per file', () async {
    final cards = previews(capacity: 2);
    unawaited(cards.read(doc('a.md')));
    reads.values.single.complete(previewed);
    await pumpEventQueue();
    final newer = doc('a.md', version: 1);
    final read = cards.read(newer);

    expect(cards.lastKnown(newer), previewed);
    reads[newer]!.complete(const PreviewNotText());
    await read;
    expect(cards.lastKnown(doc('a.md')), isA<PreviewNotText>());
    expect(cards.known(doc('a.md')), isNull);

    unawaited(cards.read(doc('b.md')));
    reads[doc('b.md')]!.complete(previewed);
    await pumpEventQueue();
    expect(cards.known(newer), isA<PreviewNotText>(), reason: 'kept: 2 files');
  });

  test('reads a few at a time, the one asked last first', () async {
    final cards = previews(readsAtOnce: 1);
    final [a, b, c] = [doc('a.md'), doc('b.md'), doc('c.md')];

    unawaited(cards.read(a));
    unawaited(cards.read(b));
    unawaited(cards.read(c));
    expect(started, [a]);

    reads[a]!.complete(previewed);
    await pumpEventQueue();

    expect(started, [a, c]);
  });

  test('drops a waiting read whose card went away', () async {
    final cards = previews(readsAtOnce: 1);
    final [a, b] = [doc('a.md'), doc('b.md')];
    unawaited(cards.read(a));
    unawaited(cards.read(b));

    cards.drop(b);
    reads[a]!.complete(previewed);
    await pumpEventQueue();

    expect(started, [a]);
  });

  test('keeps only the previews used last', () async {
    final cards = previews(capacity: 2);
    final [a, b, c] = [doc('a.md'), doc('b.md'), doc('c.md')];
    for (final document in [a, b]) {
      unawaited(cards.read(document));
      reads[document]!.complete(previewed);
      await pumpEventQueue();
    }
    cards.known(a);

    unawaited(cards.read(c));
    reads[c]!.complete(previewed);
    await pumpEventQueue();

    expect(cards.known(a), isNotNull);
    expect(cards.known(b), isNull, reason: 'used least lately');
    expect(cards.known(c), isNotNull);
  });
}
