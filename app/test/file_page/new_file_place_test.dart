import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown/truce_markdown.dart' show markdownType;

import '../support.dart';
import 'file_fixture.dart';

/// A Markdown arrival that ends only as the test says.
final class _HeldArrival implements FileArrival {
  final List<Completer<Result<Uint8List?, StoreError>>> asked = [];

  @override
  Future<Result<Uint8List?, StoreError>> arrive(Arrival arrival) {
    final answer = Completer<Result<Uint8List?, StoreError>>();
    asked.add(answer);
    return answer.future;
  }
}

void main() {
  late FileFixture fixture;
  late _HeldArrival arrival;
  late TextEditSession session;

  setUp(() async {
    fixture = await FileFixture.create();
    arrival = _HeldArrival();
    session = fixture.session(
      fixture.newFile,
      null,
      FileArrivals(appFileTypes().detector, {markdownType: arrival}),
    );
  });

  NewFile inSecondFolder() => NewFile((
    folder: fixture.folders[1],
    subfolder: null,
  ), type: appNewTextType());

  test("a new document's place changes once it arrived there", () async {
    final placed = session.place(inSecondFolder());
    expect(session.file.folder.id, folderId('f1'));

    arrival.asked.single.complete(const Ok(null));

    expect(await placed, isA<Ok<void, MoveFailure>>());
    expect(session.file.folder.id, folderId('f2'));
  });

  test("a new document stays where it was if it can't arrive", () async {
    final placed = session.place(inSecondFolder());
    arrival.asked.single.complete(const Err(StoreError.ioFailure));

    expect(
      (await placed).error,
      isA<MoveNotWritten>().having(
        (f) => f.error,
        'error',
        StoreError.ioFailure,
      ),
    );
    expect(session.file.folder.id, folderId('f1'));
  });

  test(
    'a document created while it arrives stays where it was created',
    () async {
      session.type('Milk');
      final placed = session.place(inSecondFolder());

      expect(await session.secure(.close), isTrue);
      arrival.asked.single.complete(const Ok(null));
      await placed;

      expect(fixture.onDisk('Milk.md'), 'Milk\n');
      expect(fixture.onDisk('Milk.md', index: 1), isNull);
      expect(session.file.folder.id, folderId('f1'));
    },
  );

  test('only the latest pick takes effect', () async {
    final first = session.place(inSecondFolder());
    final second = session.place(fixture.newFile);

    arrival.asked[1].complete(const Ok(null));
    await second;
    arrival.asked[0].complete(const Ok(null));
    await first;

    expect(session.file.folder.id, folderId('f1'));
  });
}
