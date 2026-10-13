import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';

import '../support.dart';

/// Proves that open notes never write on their own: a change that comes in
/// from another device is never written back, so devices running the app
/// cannot keep each other writing and use up the sync tool's file history.
void main() {
  late _Device laptop;
  late _Device phone;

  setUp(() async {
    laptop = await _Device.start('laptop', '# Todo\n- [ ] milk\n');
    phone = await _Device.start('phone', '# Todo\n- [ ] milk\n');
  });

  /// Lets the sync tool and both apps run [rounds] times; returns how often
  /// each app wrote meanwhile.
  Future<({int laptop, int phone})> runSync({int rounds = 20}) async {
    var laptopWrites = 0;
    var phoneWrites = 0;
    for (var round = 0; round < rounds; round++) {
      laptop.syncTo(phone);
      phoneWrites += await phone.runApp();
      phone.syncTo(laptop);
      laptopWrites += await laptop.runApp();
    }
    return (laptop: laptopWrites, phone: phoneWrites);
  }

  test('an edit on one device is written once, never echoed', () async {
    laptop.session.edit('# Todo\n- [x] milk\n');
    await laptop.session.flush();

    final writes = await runSync();

    expect(writes, (laptop: 0, phone: 0));
    expect(phone.session.text, '# Todo\n- [x] milk\n');
    expect(phone.session.state, EditState.saved);
  });

  test('edits on both devices end in one conflict copy, no loop', () async {
    // The phone's edit is still waiting for its save when the laptop's
    // arrives.
    phone = await _Device.start(
      'phone',
      '# Todo\n- [ ] milk\n',
      saveDelay: const Duration(hours: 1),
    );
    laptop.session.edit('# Todo\n- [x] milk\n');
    phone.session.edit('# Todo\n- [ ] milk\n- [ ] eggs\n');
    await laptop.session.flush();

    final writes = await runSync();

    expect(writes, (laptop: 0, phone: 0));
    expect(phone.session.state, EditState.changedElsewhere);

    expect(await phone.session.secure(), isTrue);
    final afterSecure = await runSync();

    expect(afterSecure, (laptop: 0, phone: 0));
    expect(phone.conflictCopies(), hasLength(1));
    expect(phone.main(), '# Todo\n- [x] milk\n');
  });

  test('a file whose time keeps changing is never rewritten', () async {
    for (var round = 0; round < 20; round++) {
      laptop.restamp(DateTime(2001, 1, 1, 0, round));
      expect(await laptop.runApp(), 0);
    }
  });

  test('a note deleted elsewhere is never recreated on its own', () async {
    laptop.session.edit('# Todo\n- [x] milk\n');
    laptop.mainFile.deleteSync();
    await laptop.session.flush();

    for (var round = 0; round < 20; round++) {
      expect(await laptop.runApp(), 0);
    }
    expect(laptop.mainFile.existsSync(), isFalse);
    expect(laptop.session.state, EditState.deletedElsewhere);
  });
}

/// One device: its copy of the synced folder, and the app with the note
/// open.
final class _Device {
  _Device._(this.dir, this.files, this.session);

  static Future<_Device> start(
    String name,
    String text, {
    Duration saveDelay = Duration.zero,
  }) async {
    final dir = tempFolder();
    File('${dir.path}/todo.md').writeAsStringSync(text);
    final folder = folderAt(dir, id: name);
    final files = NoteFiles(folder, servicesFor(folder));
    final scan = (await files.reload(_placeholder(folder))).value;
    final session = NoteEditSession(scan, files, saveDelay: saveDelay);
    addTearDown(session.dispose);
    return _Device._(dir, files, session);
  }

  final Directory dir;
  final NoteFiles files;
  final NoteEditSession session;

  File get mainFile => File('${dir.path}/todo.md');

  String main() => mainFile.readAsStringSync();

  List<File> conflictCopies() => [
    for (final file in dir.listSync().whereType<File>())
      if (file.path.contains('.sync-conflict-')) file,
  ];

  /// One poll of the app: a rescan, then any pending save. Returns how many
  /// files it wrote.
  Future<int> runApp() async {
    final before = _state();
    final latest = switch (await files.reload(session.note)) {
      Ok(:final value) => value,
      Err() => null,
    };
    session.onRescan(latest, scannedAt: DateTime.now());
    await session.flush();
    final after = _state();
    return {
      for (final key in {...before.keys, ...after.keys})
        if (before[key] != after[key]) key,
    }.length;
  }

  /// Copies the note to [other] the way Syncthing does: atomically, with
  /// this device's modification time.
  void syncTo(_Device other) {
    if (!mainFile.existsSync()) return;
    final temp = File('${other.dir.path}/.syncthing.todo.md.tmp')
      ..writeAsBytesSync(mainFile.readAsBytesSync());
    temp.setLastModifiedSync(mainFile.lastModifiedSync());
    temp.renameSync(other.mainFile.path);
  }

  /// Changes only the note's time, as some file systems and tools do.
  void restamp(DateTime time) => mainFile.setLastModifiedSync(time);

  Map<String, String> _state() => {
    for (final file in dir.listSync().whereType<File>())
      file.path: '${file.readAsBytesSync()} ${file.lastModifiedSync()}',
  };

  static Note _placeholder(NoteFolder folder) => Note(
    folder: folder,
    path: RelPath.parse('todo.md')!,
    file: TextFile.empty(),
    version: const FileVersion(0),
    modified: DateTime(2000),
  );
}
