import 'package:flutter_test/flutter_test.dart';
import 'package:truce_image_view/src/content_image.dart';

void main() {
  const box = (width: 400, height: 300);

  test('a wide picture decodes as high as the box, its sides cut', () {
    final size = ContentImage.covering(box, 5000, 1000);

    expect((size.width, size.height), (1500, 300));
  });

  test('a tall picture decodes as wide as the box', () {
    final size = ContentImage.covering(box, 1000, 4000);

    expect((size.width, size.height), (400, 1600));
  });

  test('a picture smaller than the box decodes as it is', () {
    final size = ContentImage.covering(box, 200, 100);

    expect((size.width, size.height), (null, null));
  });
}
