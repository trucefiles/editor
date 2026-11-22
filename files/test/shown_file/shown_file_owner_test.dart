import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

import '../support/fake_shown_type.dart';

final _types = ShownFileTypes([const FakeShownType()]);

Folder _folder(String id) =>
    Folder(id: folderId(id), name: id, color: 'teal', location: 'fake:$id');

final _home = _folder('home');
final _work = _folder('work');

ListedFile _listed(Folder folder, String name, {int version = 0}) => ListedFile(
  folder: folder,
  path: path(name),
  type: const FakeFileType(),
  version: FileVersion(version),
  modified: DateTime(2000),
  size: 0,
);

/// The folders as listed from [at] on, holding [files].
FolderContents _contents(List<ListedFile> files, {Moment? at}) =>
    FolderContents(
      FolderState({
        for (final folder in [_home, _work])
          folder.id: Listed(
            FolderFound(
              files: {
                for (final file in files)
                  if (file.folder.id == folder.id)
                    file.path: FileEntry(
                      file.path,
                      version: file.version,
                      modified: file.modified,
                      size: 0,
                    ),
              },
              conflicts: const {},
              subfolders: const {},
              unreadable: const [],
              marks: MarksFiles.none,
            ),
            listedAt: at ?? Moment.now(),
          ),
      }),
      folders: [_home, _work],
      types: _types,
    );

/// Writes and drafts as the owner asks them, each answered as set.
final class _Work {
  final drafts = <FolderId, FileDrafts>{};
  final created = <({FilePlace place, String title, String extension})>[];
  final moved = <({FilePlace place, String title})>[];
  bool draftsRefused = false;

  /// Folders whose drafts can't be kept.
  final refusedIn = <FolderId>{};
  bool createFails = false;
  Result<FileBytes, MoveFailure>? moveResult;

  /// Drafts in a place that is a file, so none can be kept there.
  late final _refusing = FileDrafts(
    Directory('${(File('${tempFolder().path}/file')..createSync()).path}/d'),
  );

  FileDrafts draftsIn(Folder folder) =>
      draftsRefused || refusedIn.contains(folder.id)
      ? _refusing
      : drafts.putIfAbsent(
          folder.id,
          () => FileDrafts(Directory('${tempFolder().path}/drafts')),
        );

  late final work = ShownWork(
    reload: (file) async => Ok(FileBytes(file, Uint8List(0))),
    draftsOf: draftsIn,
    create:
        (
          place, {
          required extension,
          required title,
          required bytes,
          newSubfolder = false,
        }) async {
          if (createFails) return const Err(StoreError.ioFailure);
          created.add((place: place, title: title, extension: extension));
          return Ok(
            FileBytes(_listed(place.folder, '$title$extension'), bytes),
          );
        },
    move: (file, place, {required title, required newSubfolder}) async {
      moved.add((place: place, title: title));
      return moveResult ??
          Ok(FileBytes(_listed(place.folder, '$title.md'), file.bytes));
    },
  );

  Future<List<RelPath>> draftPaths(Folder folder) async => [
    for (final head in await draftsIn(folder).heads(before: _later)) head.path,
  ];
}

final _later = DateTime.now().add(const Duration(days: 1));

NewShownFile _photo(Folder folder) => NewShownFile(
  topOf(folder),
  name: 'Photo.jpg',
  bytes: Uint8List.fromList([1, 2, 3]),
);

Future<bool> _secure(ShownFileOwner owner, SecureReason reason) =>
    answerOf<ShownInput, Secured, bool>(
      owner,
      (ticket) => SecureShown(ticket, reason),
      read: (answer) => answer.kept,
      orElse: false,
    );

Future<MoveFailure?> _place(
  ShownFileOwner owner,
  Folder folder, {
  String title = 'Photo',
}) => answerOf<ShownInput, Placed, MoveFailure?>(
  owner,
  (ticket) => PlaceShown(ticket, topOf(folder), title: title),
  read: (answer) => answer.failure,
  orElse: const MoveNotSaved(),
);

/// Once [owner] knows where its new file is kept.
Future<void> _kept(ShownFileOwner owner) async {
  bool keeping(ShownState state) =>
      state is WaitingNew && state.kept == NewKept.keeping;
  if (keeping(owner.state)) {
    await owner.changes.firstWhere((state) => !keeping(state));
  }
}

void main() {
  late _Work work;

  setUp(() => work = _Work());

  group('a file opened from its folder', () {
    test('follows a newer version as listed', () async {
      final owner = shownFileOwner(_listed(_home, 'a.md'), work.work);
      final newer = _listed(_home, 'a.md', version: 2);

      owner.send(SeeFolders(_contents([newer])));
      await owner.close();

      expect(
        owner.state,
        ShownListed(newer, content: ContentTag.listed(newer)),
      );
    });

    test('is gone once deleted elsewhere, and never written again', () async {
      final file = _listed(_home, 'a.md');
      final owner = shownFileOwner(file, work.work);

      owner.send(SeeFolders(_contents([])));
      expect(await _secure(owner, SecureReason.close), isTrue);
      await owner.close();

      expect(owner.state, ShownGone(file, content: ContentTag.listed(file)));
      expect(work.created, isEmpty);
    });

    test('moves, and a listing from before the move is old', () async {
      final file = _listed(_home, 'a.md');
      final owner = shownFileOwner(file, work.work);
      final before = Moment.now();

      expect(await _place(owner, _work, title: 'b'), isNull);
      owner.send(SeeFolders(_contents([file], at: before)));
      await owner.close();

      expect(
        owner.state,
        ShownListed(_listed(_work, 'b.md'), content: ContentTag.listed(file)),
      );
    });

    test('a move that fails says why, and the file stays', () async {
      final file = _listed(_home, 'a.md');
      final owner = shownFileOwner(file, work.work);
      work.moveResult = const Err(MoveBlockedByConflict());

      expect(await _place(owner, _work), isA<MoveBlockedByConflict>());

      expect(owner.state, ShownListed(file, content: ContentTag.listed(file)));
    });
  });

  group('the content tag', () {
    ContentTag contentOf(ShownFileOwner owner) => switch (owner.state) {
      WaitingNew(:final content) ||
      ShownListed(:final content) ||
      ShownGone(:final content) => content,
      ShownDropped() => throw StateError('No content once dropped.'),
    };

    test('of a file opened again is the same', () {
      final file = _listed(_home, 'a.md');

      expect(
        contentOf(shownFileOwner(file, work.work)),
        contentOf(shownFileOwner(file, work.work)),
      );
    });

    test('stays after the owner renames or moves the file, and once the '
        'moved file is listed', () async {
      final owner = shownFileOwner(_listed(_home, 'a.md'), work.work);
      final before = contentOf(owner);

      await _place(owner, _home, title: 'b');
      await _place(owner, _work, title: 'c');
      owner.send(SeeFolders(_contents([_listed(_work, 'c.md')])));
      await owner.close();

      expect(owner.state, isA<ShownListed>());
      expect(contentOf(owner), before);
    });

    test('changes when a move changed the bytes', () async {
      final owner = shownFileOwner(_listed(_home, 'a.md'), work.work);
      final before = contentOf(owner);
      work.moveResult = Ok(
        FileBytes(_listed(_work, 'b.md'), Uint8List.fromList([9])),
      );

      await _place(owner, _work, title: 'b');

      expect(contentOf(owner), isNot(before));
    });

    test('changes with a version the owner didn\'t write', () async {
      final owner = shownFileOwner(_listed(_home, 'a.md'), work.work);
      final before = contentOf(owner);

      owner.send(SeeFolders(_contents([_listed(_home, 'a.md', version: 2)])));
      await owner.close();

      expect(contentOf(owner), isNot(before));
    });

    test('stays once the file is gone', () async {
      final owner = shownFileOwner(_listed(_home, 'a.md'), work.work);
      final before = contentOf(owner);

      owner.send(SeeFolders(_contents([])));
      await owner.close();

      expect(owner.state, isA<ShownGone>());
      expect(contentOf(owner), before);
    });

    test('of a new file stays as it goes elsewhere and once it is written, '
        'and is its own', () async {
      final owner = newShownFileOwner(_photo(_home), work.work);
      final before = contentOf(owner);

      await _place(owner, _work, title: 'Cat');
      expect(contentOf(owner), before);
      expect(await _secure(owner, SecureReason.close), isTrue);

      expect(owner.state, isA<ShownListed>());
      expect(contentOf(owner), before);
      expect(
        contentOf(newShownFileOwner(_photo(_home), work.work)),
        isNot(before),
      );
    });
  });

  group('a new file', () {
    test('waits on the device until the user leaves', () async {
      final owner = newShownFileOwner(_photo(_home), work.work);
      await _kept(owner);

      expect(owner.state, isA<WaitingNew>());
      expect((owner.state as WaitingNew).kept, NewKept.onDevice);
      expect(await work.draftPaths(_home), [path('Photo.jpg')]);
      expect(work.created, isEmpty);
    });

    test('is written as the user leaves; its draft goes', () async {
      final owner = newShownFileOwner(_photo(_home), work.work);
      final written = owner.events.firstWhere((event) => event is NewWritten);

      expect(await _secure(owner, SecureReason.close), isTrue);

      expect(work.created.single.title, 'Photo');
      expect(work.created.single.extension, '.jpg');
      expect(((await written) as NewWritten).file.path, path('Photo.jpg'));
      expect(owner.state, isA<ShownListed>());
      expect(await work.draftPaths(_home), isEmpty);
    });

    test(
      'hidden, it is written; if it can\'t be, the device keeps it',
      () async {
        final owner = newShownFileOwner(_photo(_home), work.work);
        work.createFails = true;

        expect(await _secure(owner, SecureReason.hide), isTrue);
        expect(await _secure(owner, SecureReason.close), isFalse);

        expect(owner.state, isA<WaitingNew>());
        expect(await work.draftPaths(_home), [path('Photo.jpg')]);
      },
    );

    test('as the app ends, the device is enough', () async {
      final owner = newShownFileOwner(_photo(_home), work.work);

      expect(await _secure(owner, SecureReason.exit), isTrue);

      expect(work.created, isEmpty);
    });

    test('is written at once if the device refuses it', () async {
      work.draftsRefused = true;
      final owner = newShownFileOwner(_photo(_home), work.work);
      await _kept(owner);

      expect(owner.state, isA<ShownListed>());
      expect(work.created, hasLength(1));
    });

    test('kept nowhere, it says so and can be tried again', () async {
      work
        ..draftsRefused = true
        ..createFails = true;
      final owner = newShownFileOwner(_photo(_home), work.work);
      await _kept(owner);
      expect((owner.state as WaitingNew).kept, NewKept.nowhere);

      work.draftsRefused = false;
      final onDevice = owner.changes.firstWhere(
        (state) => state is WaitingNew && state.kept == NewKept.onDevice,
      );
      owner.send(const KeepNew());

      await onDevice;
      expect(await work.draftPaths(_home), [path('Photo.jpg')]);
    });

    test('its folder removed, it is kept nowhere, with no draft or write '
        'again', () async {
      final owner = newShownFileOwner(_photo(_home), work.work);
      await _kept(owner);
      final writes = await work.draftPaths(_home);

      final changed = owner.changes.first;
      owner.send(const NewFolderRemoved());

      expect(await changed, isA<WaitingNew>());
      expect((owner.state as WaitingNew).kept, NewKept.nowhere);
      expect(await work.draftPaths(_home), writes);
      expect(work.created, isEmpty);
    });

    test('goes to another folder: kept there, then dropped here', () async {
      final owner = newShownFileOwner(_photo(_home), work.work);

      expect(await _place(owner, _work, title: 'Cat'), isNull);

      expect((owner.state as WaitingNew).file.place.folder, _work);
      expect(await work.draftPaths(_work), [path('Cat.jpg')]);
      expect(await work.draftPaths(_home), isEmpty);
      expect(work.created, isEmpty);
    });

    group('moved to a folder that refuses its draft', () {
      /// The new file, kept in home, then placed in work, which refuses
      /// its draft and its write.
      Future<ShownFileOwner> placedInRefusingWork() async {
        final owner = newShownFileOwner(_photo(_home), work.work);
        await _kept(owner);
        work
          ..refusedIn.add(_work.id)
          ..createFails = true;
        await _place(owner, _work, title: 'Cat');
        work
          ..refusedIn.clear()
          ..createFails = false;
        return owner;
      }

      test('stays kept where it was', () async {
        work
          ..refusedIn.add(_work.id)
          ..createFails = true;
        final owner = newShownFileOwner(_photo(_home), work.work);
        await _kept(owner);
        await _place(owner, _work, title: 'Cat');

        expect((owner.state as WaitingNew).kept, NewKept.nowhere);
        expect(await work.draftPaths(_home), [path('Photo.jpg')]);
      });

      test('kept there later, it is dropped where it was', () async {
        final owner = await placedInRefusingWork();
        final onDevice = owner.changes.firstWhere(
          (state) => state is WaitingNew && state.kept == NewKept.onDevice,
        );
        owner.send(const KeepNew());
        await onDevice;

        expect(await work.draftPaths(_work), [path('Cat.jpg')]);
        expect(await work.draftPaths(_home), isEmpty);
      });

      test('written, no draft is left anywhere', () async {
        final owner = await placedInRefusingWork();

        expect(await _secure(owner, SecureReason.close), isTrue);

        expect(work.created.single.place.folder, _work);
        expect(await work.draftPaths(_home), isEmpty);
        expect(await work.draftPaths(_work), isEmpty);
      });

      test('dropped, no draft is left anywhere', () async {
        final owner = await placedInRefusingWork();

        owner.send(const DropNew());
        expect(await _secure(owner, SecureReason.close), isTrue);

        expect(await work.draftPaths(_home), isEmpty);
        expect(await work.draftPaths(_work), isEmpty);
      });
    });

    test('dropped, its draft goes and nothing is written', () async {
      final owner = newShownFileOwner(_photo(_home), work.work);

      owner.send(const DropNew());
      expect(await _secure(owner, SecureReason.close), isTrue);

      expect(owner.state, isA<ShownDropped>());
      expect(await work.draftPaths(_home), isEmpty);
      expect(work.created, isEmpty);
    });
  });
}
