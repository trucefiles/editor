import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/file_page/text_edit_page_controller.dart';
import 'package:truce_editor/file_page/view_page_controller.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';

/// A pick that moved nothing, and nothing failed.
final _nothingMoved = isA<Ok<ListedFile?, MoveFailure>>().having(
  (ok) => ok.value,
  'moved',
  isNull,
);

void main() {
  final folder = folderAt(Directory('/pictures'), id: 'pictures');
  final picture = Uint8List.fromList([1, 2, 3]);
  late FileDrafts drafts;
  late List<String> created;
  late List<Uint8List> deleted;
  late List<String> moved;
  var createFails = false;
  var reach = Reach.reachable;

  setUp(() {
    drafts = tempDrafts();
    created = [];
    deleted = [];
    moved = [];
    createFails = false;
    reach = Reach.reachable;
  });

  ShownWork work() => ShownWork(
    reload: (file) async => Ok(FileBytes(file, picture)),
    draftsOf: (_) => drafts,
    create:
        (
          place, {
          required extension,
          required title,
          required bytes,
          newSubfolder = false,
        }) async {
          if (createFails) return const Err(StoreError.ioFailure);
          created.add('$title$extension');
          return Ok(
            FileBytes(listedFile(folder, name: '$title$extension'), bytes),
          );
        },
    move: (file, place, {required title, required newSubfolder}) async {
      moved.add(title);
      return Ok(FileBytes(listedFile(folder, name: '$title.jpg'), file.bytes));
    },
  );

  ViewPageController controllerOf(ShownFileOwner owner) {
    final controller = ViewPageController(
      owner,
      read: (file) async => Ok(FileBytes(file, picture)),
      reachOf: (_) => reach,
      reachSettled: (_) async => reach,
      delete: (file, bytes) async {
        deleted.add(bytes);
        return Ok((
          file: file,
          bytes: bytes,
          mark: FileMark.none,
          settings: FileSettings.defaults,
        ));
      },
      settingsOf: (_) => FileSettings.defaults,
      editSettings: (_, _) async {},
      endWait: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  ViewPageController newPhoto() => controllerOf(
    newShownFileOwner(
      NewShownFile(topOf(folder), name: 'Photo.jpg', bytes: picture),
      work(),
    ),
  );

  Future<List<RelPath>> draftPaths() async => [
    for (final head in await drafts.heads(
      before: DateTime.now().add(const Duration(days: 1)),
    ))
      head.path,
  ];

  test('a new image is written as the user leaves, and says where', () async {
    final page = newPhoto();

    expect(await page.mayGo(SecureReason.close, () async => false), isTrue);

    expect(created, ['Photo.jpg']);
    expect(page.written?.path, path('Photo.jpg'));
    expect(page.title, 'Photo');
  });

  test('while its folder is out of reach, it waits on the device', () async {
    final page = newPhoto();
    await eventually(() async => (await draftPaths()).isNotEmpty);
    createFails = true;
    reach = Reach.unreachable;

    expect(await page.keep(SecureReason.close), isTrue);

    expect(page.written, isNull);
    expect(await draftPaths(), [path('Photo.jpg')]);
  });

  test('if it can be written nowhere, the user may drop it', () async {
    final page = newPhoto();
    await eventually(() async => (await draftPaths()).isNotEmpty);
    createFails = true;
    var asked = false;

    final left = await page.mayGo(SecureReason.close, () async => asked = true);

    expect(left, isTrue);
    expect(asked, isTrue);
    await eventually(() async => (await draftPaths()).isEmpty);
    expect(page.state, isA<ShownDropped>());
  });

  test('pin or color writes a new image first', () async {
    final page = newPhoto();
    ListedFile? actedOn;

    expect(await page.withFile((file) => actedOn = file), isTrue);

    expect(actedOn?.path, path('Photo.jpg'));
    expect(created, ['Photo.jpg']);
  });

  test('deleting a new image drops it; nothing is written', () async {
    final page = newPhoto();

    expect(await page.deleteFile(), isA<NewDropped>());
    expect(await page.keep(SecureReason.close), isTrue);

    expect(created, isEmpty);
  });

  test('deleting a listed image deletes it as read, for undo', () async {
    final page = controllerOf(
      shownFileOwner(listedFile(folder, name: 'a.jpg'), work()),
    );

    expect(await page.deleteFile(), isA<DeletedForUndo>());

    expect(deleted, [picture]);
  });

  group('a place and name picked', () {
    PickedPlace named(String name) =>
        (place: topOf(folder), name: name, newSubfolder: false);

    test('with an empty name, a new image keeps its name', () async {
      final page = newPhoto();

      expect(await page.placeAt(named(' ')), _nothingMoved);

      expect(page.title, 'Photo');
      expect(created, isEmpty);
    });

    test('the same place and name does nothing', () async {
      final page = controllerOf(
        shownFileOwner(listedFile(folder, name: 'a.jpg'), work()),
      );

      expect(await page.placeAt(named('a')), _nothingMoved);

      expect(moved, isEmpty);
    });

    test('another name renames the image, and says where it is', () async {
      final page = controllerOf(
        shownFileOwner(listedFile(folder, name: 'a.jpg'), work()),
      );

      final placed = await page.placeAt(named('Cat'));

      expect(
        (placed as Ok<ListedFile?, MoveFailure>).value?.path,
        path('Cat.jpg'),
      );
      expect(moved, ['Cat']);
    });
  });

  test('a newer version shows as other content', () async {
    final file = listedFile(folder, name: 'a.jpg');
    final page = controllerOf(shownFileOwner(file, work()));
    final before = page.content!.id;
    final newer = listedFile(folder, name: 'a.jpg', version: 2);

    page.observe(contentsFinding([newer], folders: [folder]));
    await eventually(() async => page.listed == newer);

    expect(page.content!.id, isNot(before));
  });
}
