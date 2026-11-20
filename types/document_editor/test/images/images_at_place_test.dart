import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/src/markdown/images_at_place.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;
import 'package:truce_markdown_images/truce_markdown_images.dart';
import 'package:truce_test_support/truce_test_support.dart';

const _name = 'img-0123456789abcdef.png';

/// A folder of the fake plugin whose document images are kept apart.
FolderServices _services(FakeFolder raw) => folderServices(
  raw,
  reach: folderReach(raw.files),
  handles: (file) => file.name.endsWith('.md'),
  keptApart: ImageNames.isKept,
  checkEvery: () => const Duration(seconds: 1),
  backupsPath: tempFolder().path,
  deviceId: '0123456789abcdef',
  wrote: (_) {},
);

void main() {
  late Map<FolderId, FakeFolder> folders;
  late EditorGate gate;
  late List<String> hints;
  late ImagesAtPlace images;

  DocumentImageStore storeOf(FolderId folder) =>
      DocumentImageStore(_services(folders[folder]!));

  String text() => (gate.state.content as md.MarkdownContent).text;

  bool has(String folder) => folders[folderId(folder)]!.files.files.containsKey(
    ImageNames.pathOf(_name),
  );

  /// The document holding [start], at [at] in folder f1.
  void open(String start, {String at = 'doc.md'}) {
    gate = EditorGate(
      md.editorOwner(
        md.MarkdownStart.read(start),
        version: const Version(1),
        mode: md.EditMode.markdown,
        startTimer: ManualTimers().start,
      ),
    );
    addTearDown(gate.dispose);
    images = ImagesAtPlace(
      gate,
      storeOf,
      place: (folder: folderId('f1'), documentFolder: path(at).parent),
    );
  }

  /// The document is at [at] in [folder] now; its steps ended.
  Future<void> moveTo(String folder, String at) =>
      images.at(folderId(folder), path(at), hint: hints.add);

  setUp(() {
    final plugin = FakePlugin();
    folders = {
      for (final name in ['f1', 'f2']) folderId(name): plugin.folder(name),
    };
    folders[folderId('f1')]!.files.put(ImageNames.pathOf(_name).value, 'image');
    hints = [];
  });

  test('an image added links from where the document is', () async {
    open('a', at: 'x/doc.md');
    final links = <String>[];

    await images.add(Uint8List(1), extension: 'png', insert: links.add);

    expect(links.single, startsWith('../document-images/img-'));
    expect(links.single, endsWith('.png'));
  });

  test(
    'to another depth, its links change as one step undo takes back',
    () async {
      open('![](document-images/$_name) ![](pics/a.png)');

      await moveTo('f1', 'x/y/doc.md');

      expect(text(), '![](../../document-images/$_name) ![](pics/a.png)');
      expect(gate.state.status.canUndo, isTrue);
    },
  );

  test('at the same depth, nothing changes', () async {
    open('![](../document-images/$_name)', at: 'x/doc.md');

    await moveTo('f1', 'y/doc.md');

    expect(text(), '![](../document-images/$_name)');
    expect(gate.state.status.canUndo, isFalse);
  });

  test('to another folder, its images come along first', () async {
    open('![](document-images/$_name)');

    await moveTo('f2', 'x/doc.md');

    expect(has('f2'), isTrue);
    expect(text(), '![](../document-images/$_name)');
  });

  test('images that can not come along keep their links, and a hint '
      'tells', () async {
    open('![](document-images/$_name)');
    folders[folderId('f2')]!.files.failWith = StoreError.ioFailure;

    await moveTo('f2', 'x/doc.md');

    expect(hints, hasLength(1));
    expect(text(), '![](document-images/$_name)');
  });

  /// Puts [link] as an image at the end of the text, as the editor does.
  void insert(String link) => gate.send(
    (now) => md.EditText(
      editTo(text(), '${text()}\n\n![]($link)'),
      revision: now.revision,
    ),
  );

  bool hasIn(String folder, String link) => folders[folderId(folder)]!
      .files
      .files
      .containsKey(ImageNames.pathOf(link.split('/').last));

  test('an image added right before the place changes comes along', () async {
    open('a');
    final links = <String>[];

    await images.add(
      Uint8List(1),
      extension: 'png',
      insert: (link) => insert((links..add(link)).last),
    );
    await moveTo('f2', 'doc.md');

    expect(hasIn('f2', links.single), isTrue);
  });

  test('an image being added as the place changes comes along', () async {
    open('a');
    final links = <String>[];

    final added = images.add(
      Uint8List(1),
      extension: 'png',
      insert: (link) => insert((links..add(link)).last),
    );
    await moveTo('f2', 'doc.md');
    await added;

    expect(hasIn('f1', links.single), isTrue);
    expect(hasIn('f2', links.single), isTrue);
  });

  test(
    'an image added while the place changes links from the new place',
    () async {
      open('a');
      final links = <String>[];

      unawaited(images.at(folderId('f2'), path('x/doc.md'), hint: hints.add));
      await images.add(Uint8List(1), extension: 'png', insert: links.add);

      expect(links.single, startsWith('../document-images/'));
      final name = links.single.split('/').last;
      expect(
        folders[folderId('f2')]!.files.files.containsKey(
          ImageNames.pathOf(name),
        ),
        isTrue,
      );
    },
  );
}
