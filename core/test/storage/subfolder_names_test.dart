import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// The names [names] found in [folder]; fails the test on an error.
Future<List<String>> _namesIn(SubfolderNames names, String? folder) async =>
    switch (await names.namesIn(
      folder == null ? null : RelPath.parse(folder),
    )) {
      Ok(:final value) => value,
      Err(:final error) => fail('$error'),
    };

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('truce_subfolders');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  test('names only the folders directly in a folder, sorted', () async {
    Directory('${dir.path}/work/deep').createSync(recursive: true);
    Directory('${dir.path}/home').createSync();
    File('${dir.path}/todo.md').writeAsStringSync('x');
    Directory('${dir.path}/work/plans').createSync();
    final names = LocalSubfolderNames(dir.path);

    expect(await _namesIn(names, null), ['home', 'work']);
    expect(await _namesIn(names, 'work'), ['deep', 'plans']);
  });

  test('never follows a link to a folder', () async {
    Directory('${dir.path}/real').createSync();
    Link('${dir.path}/link').createSync('${dir.path}/real');

    expect(await _namesIn(LocalSubfolderNames(dir.path), null), ['real']);
  });

  test('a folder that is gone is not found', () async {
    final names = LocalSubfolderNames(dir.path);

    expect(
      await names.namesIn(RelPath.parse('gone')),
      isA<Err<List<String>, StoreError>>().having(
        (err) => err.error,
        'error',
        StoreError.notFound,
      ),
    );
  });

  test('shown by a filter, names only the folders it lets through', () async {
    Directory('${dir.path}/work/.cache').createSync(recursive: true);
    Directory('${dir.path}/work/tool').createSync();
    Directory('${dir.path}/work/plans').createSync();
    Directory('${dir.path}/.git').createSync();
    final names = LocalSubfolderNames(dir.path)
        .shownBy(VisibleFileFilter((path) => path.name == 'tool'));

    expect(await _namesIn(names, null), ['work']);
    expect(await _namesIn(names, 'work'), ['plans']);
  });
}
