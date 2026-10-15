import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/storage/json_file.dart';

import '../support.dart';

void main() {
  late File file;
  late JsonFile json;

  setUp(() {
    file = File('${tempFolder().path}/settings/a.json');
    json = JsonFile(file);
  });

  test('is missing before the first write', () async {
    expect((await json.read()).error, JsonFileError.missing);
  });

  test('writes at the same time all land, the last one wins', () async {
    final results = await Future.wait([
      for (var i = 0; i < 20; i++) JsonFile(file).write({'n': i}),
    ]);

    expect(results, everyElement(isA<Ok<void, JsonFileError>>()));
    expect((await json.read()).value, {'n': 19});
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
    file
      ..createSync(recursive: true)
      ..writeAsStringSync('{not json');

    expect((await json.read()).error, JsonFileError.corrupt);
  });

  test('is unwritable when the parent is a file', () async {
    final blocked = JsonFile(File('${file.path}/b.json'));
    file
      ..createSync(recursive: true)
      ..writeAsStringSync('1');

    expect(await blocked.write(2), isA<Err<void, JsonFileError>>());
    expect((await blocked.read()).error, JsonFileError.missing);
  });
}
