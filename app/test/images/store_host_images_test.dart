import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_image_store/truce_document_image_store.dart';
import 'package:truce_editor/images/store_host_images.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const name = 'img-0123456789abcdef.png';
  late StoreHostImages images;

  setUp(() {
    final raw = FakePlugin().folder('f1');
    raw.files.put('document-images/$name', 'png');
    final services = folderServices(
      raw,
      reach: folderReach(raw.files),
      handles: (file) => file.name.endsWith('.md'),
      keptApart: ImageNames.isKept,
      checkEvery: () => const Duration(seconds: 1),
      backupsPath: tempFolder().path,
      deviceId: '0123456789abcdef',
      wrote: (_) {},
    );
    images = StoreHostImages(DocumentImageStore(services), path('a'));
  });

  test('an image of ours is kept by its name, wherever its link points', () {
    expect(images.keptAt('x/y/$name'), path('document-images/$name'));
    expect(images.keptAt('pic.png'), isNull);
  });
}
