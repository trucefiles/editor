import 'package:truce_core/truce_core.dart';
import 'package:truce_document_image_store/truce_document_image_store.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// A folder of the fake plugin whose document images are kept apart, as
/// the app wires it.
final class ImageFolder {
  ImageFolder(String name, {FakePlugin? plugin})
    : raw = (plugin ?? FakePlugin()).folder(name) {
    services = folderServices(
      raw,
      reach: folderReach(raw.files),
      handles: (file) => file.name.endsWith('.md'),
      keptApart: ImageNames.isKept,
      checkEvery: () => const Duration(seconds: 1),
      backupsPath: tempFolder().path,
      deviceId: '0123456789abcdef',
      wrote: wrote.addAll,
    );
    store = DocumentImageStore(services, now: () => now);
  }

  final FakeFolder raw;
  late final FolderServices services;
  late final DocumentImageStore store;

  /// The paths each write was told of.
  final List<RelPath> wrote = [];

  /// The time the store sees.
  DateTime now = DateTime(2026, 11, 19, 12);

  MemoryFileStore get files => raw.files;

  /// Whether [name] is kept in the store.
  bool has(String name) => files.files.containsKey(ImageNames.pathOf(name));

  /// Puts an image [name] straight into the store, as another device's
  /// would arrive.
  void putImage(String name) =>
      files.put(ImageNames.pathOf(name).value, 'image $name');
}

const nameA = 'img-0123456789abcdef.png';
const nameB = 'img-fedcba9876543210.jpg';
