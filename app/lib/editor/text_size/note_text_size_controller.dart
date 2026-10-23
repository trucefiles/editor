import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../../storage/app_storage.dart';
import 'note_text_size.dart';
import 'note_text_size_store.dart';

final noteTextSizeStoreProvider = Provider<NoteTextSizeStore>(
  (ref) => NoteTextSizeStore(
    File('${ref.watch(appStorageProvider).settingsPath}/note_text_size.json'),
  ),
);

final noteTextSizeProvider =
    AsyncNotifierProvider<NoteTextSizeController, NoteTextSize>(
      NoteTextSizeController.new,
    );

/// The setting of how large notes' text shows on this device.
class NoteTextSizeController extends AsyncNotifier<NoteTextSize> {
  final _changes = Pool(1);

  @override
  Future<NoteTextSize> build() => ref.watch(noteTextSizeStoreProvider).load();

  /// Takes [size] once the setting is loaded, so screens show it; saves
  /// it after every earlier change. The same size again changes nothing.
  Future<void> set(NoteTextSize size) async {
    if (await future == size) return;
    state = AsyncData(size);
    await _changes.withResource(
      () => ref.read(noteTextSizeStoreProvider).save(size),
    );
  }

  /// The size [next] makes of the current one, once loaded.
  Future<void> change(NoteTextSize Function(NoteTextSize size) next) async =>
      set(next(await future));
}
