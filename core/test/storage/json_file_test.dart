import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';


void main() {
  late Directory dir;
  late File file;
  late JsonFile json;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('truce_json_file');
    file = File('${dir.path}/settings/a.json');
    json = JsonFile(file);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('is missing before the first write', () async {
    expect((await json.read()).error, JsonFileError.missing);
  });

  test('writes at the same time all land, the last one wins', () async {
    final results = await Future.wait([
      for (var i = 0; i < 20; i++) json.write({'n': i}),
    ]);

    expect(results, everyElement(isA<Ok<void, JsonFileError>>()));
    expect((await json.read()).value, {'n': 19});
  });

  test('a read waits for the write before it', () async {
    unawaited(json.write({'a': 1}));

    expect((await json.read()).value, {'a': 1});
  });

  test('reads back what was written', () async {
    await json.write({
      'a': [1, true],
    });

    expect((await json.read()).value, {
      'a': [1, true],
    });
  });

  test('leaves no temp file behind', () async {
    await json.write(1);

    expect(file.parent.listSync().map((e) => e.path), [file.path]);
  });

  test('is corrupt when the file holds no JSON', () async {
    file.writeCreatingFolders('{not json');

    expect((await json.read()).error, JsonFileError.corrupt);
  });

  test('is unwritable when the parent is a file', () async {
    final blocked = JsonFile(File('${file.path}/b.json'));
    file.writeCreatingFolders('1');

    expect(await blocked.write(2), isA<Err<void, JsonFileError>>());
    expect((await blocked.read()).error, JsonFileError.missing);
  });
}
