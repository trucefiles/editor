import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../storage/app_storage.dart';
import 'text_zoom.dart';
import 'text_zoom_store.dart';
import 'text_zoom_target.dart';

/// The store of the zoom of [target] in [storage].
TextZoomStore textZoomStoreIn(AppStorage storage, TextZoomTarget target) =>
    TextZoomStore(
      File(
        '${storage.settingsPath}/${switch (target) {
          TextZoomTarget.notes => 'note_text_size.json',
          TextZoomTarget.app => 'app_text_size.json',
        }}',
      ),
    );

/// Every saved zoom in [storage], read before the app shows its first
/// frame, so text never shows at another size first.
Future<Map<TextZoomTarget, TextZoom>> loadTextZooms(AppStorage storage) async {
  final zooms = await Future.wait([
    for (final target in TextZoomTarget.values)
      textZoomStoreIn(storage, target).load(),
  ]);
  return Map.fromIterables(TextZoomTarget.values, zooms);
}

/// Set in `main` once [loadTextZooms] is done; a target missing here
/// starts at [TextZoom.normal].
final loadedTextZoomsProvider = Provider<Map<TextZoomTarget, TextZoom>>(
  (ref) => const {},
);

final textZoomStoreProvider = Provider.family<TextZoomStore, TextZoomTarget>(
  (ref, target) => textZoomStoreIn(ref.watch(appStorageProvider), target),
);

final textZoomProvider =
    NotifierProvider.family<TextZoomController, TextZoom, TextZoomTarget>(
      TextZoomController.new,
    );

/// The setting of how large the text of [target] shows on this device.
class TextZoomController extends Notifier<TextZoom> {
  TextZoomController(this.target);

  final TextZoomTarget target;
  final _changes = Pool(1);

  @override
  TextZoom build() =>
      ref.read(loadedTextZoomsProvider)[target] ?? TextZoom.normal;

  /// Takes [zoom] at once, so screens show it; saves it after every
  /// earlier change. The same zoom again changes nothing.
  Future<void> set(TextZoom zoom) async {
    if (zoom == state) return;
    state = zoom;
    await _changes.withResource(
      () => ref.read(textZoomStoreProvider(target)).save(zoom),
    );
  }

  /// The zoom [next] makes of the current one.
  Future<void> change(TextZoom Function(TextZoom zoom) next) =>
      set(next(state));
}
