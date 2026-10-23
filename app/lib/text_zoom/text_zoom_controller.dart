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

/// Every zoom's store, and the zoom each held at start: read before the
/// app shows its first frame, so text never shows at another size first.
final class SavedTextZooms {
  SavedTextZooms._(this._stores, this._zooms);

  /// Reads every zoom saved in [storage].
  static Future<SavedTextZooms> load(AppStorage storage) async {
    final stores = {
      for (final target in TextZoomTarget.values)
        target: textZoomStoreIn(storage, target),
    };
    final zooms = await Future.wait([
      for (final target in TextZoomTarget.values) stores[target]!.load(),
    ]);
    return SavedTextZooms._(
      stores,
      Map.fromIterables(TextZoomTarget.values, zooms),
    );
  }

  final Map<TextZoomTarget, TextZoomStore> _stores;
  final Map<TextZoomTarget, TextZoom> _zooms;

  TextZoomStore storeOf(TextZoomTarget target) => _stores[target]!;

  /// The zoom of [target] when the app started.
  TextZoom atStart(TextZoomTarget target) => _zooms[target]!;
}

/// Set in `main` once [SavedTextZooms.load] is done.
final savedTextZoomsProvider = Provider<SavedTextZooms>(
  (ref) => throw UnimplementedError('savedTextZoomsProvider is set in main'),
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
  TextZoom build() => ref.read(savedTextZoomsProvider).atStart(target);

  /// Takes [zoom] at once, so screens show it; saves it after every
  /// earlier change. The same zoom again changes nothing.
  Future<void> set(TextZoom zoom) async {
    if (zoom == state) return;
    state = zoom;
    await _changes.withResource(
      () => ref.read(savedTextZoomsProvider).storeOf(target).save(zoom),
    );
  }

  /// The zoom [next] makes of the current one.
  Future<void> change(TextZoom Function(TextZoom zoom) next) =>
      set(next(state));
}
