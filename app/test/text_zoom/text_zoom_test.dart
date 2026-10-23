import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_controller.dart';
import 'package:truce_editor/text_zoom/text_zoom_store.dart';
import 'package:truce_editor/text_zoom/text_zoom_target.dart';

import '../support.dart';

void main() {
  group('size', () {
    test('goes in steps from the smallest to the largest', () {
      expect(TextZoom.closestTo(114).percent, 110);
      expect(TextZoom.closestTo(116).percent, 120);
      expect(TextZoom.closestTo(10).percent, TextZoom.min);
      expect(TextZoom.closestTo(900).percent, TextZoom.max);
    });

    test('a step larger or smaller stops at the ends', () {
      expect(TextZoom.normal.larger.percent, 110);
      expect(TextZoom.normal.smaller.percent, 90);
      expect(TextZoom.closestTo(TextZoom.max).larger.percent, 200);
      expect(TextZoom.closestTo(TextZoom.min).smaller.percent, 80);
    });

    test('reads only the sizes there are', () {
      expect(TextZoom.fromJson(130)?.percent, 130);
      expect(TextZoom.fromJson(135), isNull);
      expect(TextZoom.fromJson(300), isNull);
      expect(TextZoom.fromJson('130'), isNull);
    });

    test('scales by its percent', () {
      expect(TextZoom.closestTo(150).factor, 1.5);
    });
  });

  group('store', () {
    late File file;
    late TextZoomStore store;

    setUp(() {
      file = File('${tempFolder().path}/settings/note_text_size.json');
      store = TextZoomStore(file);
    });

    test('is the base size until the user chooses another', () async {
      expect(await store.load(), TextZoom.normal);
    });

    test('keeps the size', () async {
      await store.save(TextZoom.closestTo(140));
      expect(await store.load(), TextZoom.closestTo(140));
    });

    test('falls back to the base size for an unreadable file', () async {
      file.writeCreatingFolders('{not json');
      expect(await store.load(), TextZoom.normal);
    });

    test('falls back to the base size for a size there is not', () async {
      file.writeCreatingFolders('{"percent": 999}');
      expect(await store.load(), TextZoom.normal);
    });
  });

  group('settings', () {
    late AppStorage storage;

    setUp(() => storage = AppStorage(tempFolder().path));

    /// The app as `main` starts it on [storage]: the zooms loaded first.
    Future<ProviderContainer> start() async {
      final container = ProviderContainer(
        overrides: [
          appStorageProvider.overrideWithValue(storage),
          loadedTextZoomsProvider.overrideWithValue(
            await loadTextZooms(storage),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    TextZoom zoomOf(ProviderContainer app, TextZoomTarget target) =>
        app.read(textZoomProvider(target));

    test('start at the base size', () async {
      final app = await start();
      expect(zoomOf(app, TextZoomTarget.notes), TextZoom.normal);
      expect(zoomOf(app, TextZoomTarget.app), TextZoom.normal);
    });

    test('are there from the start, as saved', () async {
      final first = await start();
      await first
          .read(textZoomProvider(TextZoomTarget.notes).notifier)
          .change((zoom) => zoom.larger);
      await first
          .read(textZoomProvider(TextZoomTarget.app).notifier)
          .set(TextZoom.closestTo(150));

      final next = await start();
      expect(zoomOf(next, TextZoomTarget.notes), TextZoom.closestTo(110));
      expect(zoomOf(next, TextZoomTarget.app), TextZoom.closestTo(150));
    });

    test('change one at a time', () async {
      final app = await start();
      await app
          .read(textZoomProvider(TextZoomTarget.app).notifier)
          .set(TextZoom.closestTo(120));

      expect(zoomOf(app, TextZoomTarget.app), TextZoom.closestTo(120));
      expect(zoomOf(app, TextZoomTarget.notes), TextZoom.normal);
    });

    test('keep the note zoom saved by earlier versions', () async {
      File('${storage.settingsPath}/note_text_size.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"percent": 130}');

      final app = await start();
      expect(zoomOf(app, TextZoomTarget.notes), TextZoom.closestTo(130));
      expect(zoomOf(app, TextZoomTarget.app), TextZoom.normal);
    });
  });
}
