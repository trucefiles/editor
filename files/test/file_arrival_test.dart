import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

const _notes = FileType('notes');

/// Writes `moved` or `restored` after a file's text; fails with
/// [failWith].
final class _Marks implements FileArrival {
  final List<Arrival> seen = [];
  StoreError? failWith;

  @override
  Future<Result<Uint8List?, StoreError>> arrive(Arrival arrival) async {
    seen.add(arrival);
    if (failWith case final error?) return Err(error);
    final text = utf8.decode(arrival.bytes);
    final mark = switch (arrival.by) {
      ArrivalBy.move => 'moved',
      ArrivalBy.restore => 'restored',
    };
    return Ok(Uint8List.fromList(utf8.encode('$text $mark')));
  }
}

void main() {
  late _Marks marks;
  late FileArrivals arrivals;
  final folder = Folder(
    id: folderId('f1'),
    name: 'f1',
    color: 'teal',
    location: 'fake:f1',
  );
  final to = (folder: folder, subfolder: path('a'));

  setUp(() {
    marks = _Marks();
    arrivals = FileArrivals(const ExtensionFileTypeDetector({'nt': _notes}), {
      _notes: marks,
    });
  });

  Uint8List file(String text) => Uint8List.fromList(utf8.encode(text));
  String textOf(Uint8List bytes) => utf8.decode(bytes);

  test('a moved file is as its type says, told where it goes', () async {
    final moved = await arrivals.moved(
      file('x'),
      folder: folder,
      from: path('b.nt'),
      to: to,
    );

    expect(textOf(moved.value!), 'x moved');
    final (:from, to: place, :by, folder: _, bytes: _) = marks.seen.single;
    expect((from, place, by), (path('b.nt'), to, ArrivalBy.move));
  });

  test('a move fails as its type fails', () async {
    marks.failWith = StoreError.ioFailure;

    final moved = await arrivals.moved(
      file('x'),
      folder: folder,
      from: path('b.nt'),
      to: to,
    );

    expect(moved.error, StoreError.ioFailure);
  });

  test('a restored file is as its type says, else as it was', () async {
    final restored = await arrivals.restored(
      file('x'),
      folder: folder,
      from: path('b.nt'),
      to: to,
    );
    expect(textOf(restored), 'x restored');

    marks.failWith = StoreError.ioFailure;
    expect(
      textOf(
        await arrivals.restored(
          file('x'),
          folder: folder,
          from: path('b.nt'),
          to: to,
        ),
      ),
      'x',
    );
  });

  test('a file restored at its own place is told so', () async {
    await arrivals.restored(file('x'), folder: folder, from: path('a/b.nt'));

    final (:to, :by, folder: _, from: _, bytes: _) = marks.seen.single;
    expect(
      (to, by),
      ((folder: folder, subfolder: path('a')), ArrivalBy.restore),
    );
  });

  test('a type without a step keeps its files as they are', () async {
    final moved = await arrivals.moved(
      file('x'),
      folder: folder,
      from: path('b.txt'),
      to: to,
    );

    expect(moved.value, isNull);
    expect(marks.seen, isEmpty);
  });
}
