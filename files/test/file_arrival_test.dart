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
    final mark = arrival.restored ? 'restored' : 'moved';
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

  TextFile file(String text) =>
      TextFile.decode(Uint8List.fromList(utf8.encode(text)))!;

  test('a moved file is as its type says, told where it goes', () async {
    final moved = await arrivals.moved(
      file('x'),
      folder: folder,
      from: path('b.nt'),
      to: to,
    );

    expect(moved.value.text, 'x moved');
    final (:from, to: place, :restored, folder: _, bytes: _) =
        marks.seen.single;
    expect((from, place, restored), (path('b.nt'), to, false));
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
    expect(restored, 'x restored');

    marks.failWith = StoreError.ioFailure;
    expect(
      await arrivals.restored(
        file('x'),
        folder: folder,
        from: path('b.nt'),
        to: to,
      ),
      'x',
    );
  });

  test('a type without a step keeps its files as they are', () async {
    final moved = await arrivals.moved(
      file('x'),
      folder: folder,
      from: path('b.txt'),
      to: to,
    );

    expect(moved.value.text, 'x');
    expect(marks.seen, isEmpty);
  });
}
