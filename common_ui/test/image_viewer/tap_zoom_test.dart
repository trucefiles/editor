import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/src/image_viewer/tap_zoom.dart';

void main() {
  const spot = Offset(40, 70);

  test('not zoomed in, it zooms in, keeping the spot in place', () {
    final zoomed = tapZoomed(zoomedIn: false, spot: spot, zoom: 2.5);

    expect(zoomed.getMaxScaleOnAxis(), 2.5);
    expect(MatrixUtils.transformPoint(zoomed, spot), spot);
  });

  test('zoomed in, it goes back to fit', () {
    expect(
      tapZoomed(zoomedIn: true, spot: spot, zoom: 2.5),
      Matrix4.identity(),
    );
  });
}
