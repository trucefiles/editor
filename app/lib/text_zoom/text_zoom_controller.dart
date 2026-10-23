import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../storage/app_storage.dart';
import 'text_zoom.dart';
import 'text_zoom_store.dart';

final textZoomStoreProvider = Provider<TextZoomStore>(
  (ref) => TextZoomStore(
    // Named from when it held the text size of notes only.
    File('${ref.watch(appStorageProvider).settingsPath}/note_text_size.json'),
  ),
);

final textZoomProvider = AsyncNotifierProvider<TextZoomController, TextZoom>(
  TextZoomController.new,
);

/// The setting of how large all text in the app shows on this device.
class TextZoomController extends AsyncNotifier<TextZoom> {
  final _changes = Pool(1);

  @override
  Future<TextZoom> build() => ref.watch(textZoomStoreProvider).load();

  /// Takes [zoom] once the setting is loaded, so screens show it; saves
  /// it after every earlier change. The same zoom again changes nothing.
  Future<void> set(TextZoom zoom) async {
    if (await future == zoom) return;
    state = AsyncData(zoom);
    await _changes.withResource(
      () => ref.read(textZoomStoreProvider).save(zoom),
    );
  }

  /// The zoom [next] makes of the current one, once loaded.
  Future<void> change(TextZoom Function(TextZoom zoom) next) async =>
      set(next(await future));
}
