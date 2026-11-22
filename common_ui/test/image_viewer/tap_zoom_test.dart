import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/src/image_viewer/tap_zoom.dart';

void main() {
  const spot = Offset(40, 70);

  test('from fit it zooms in, keeping the spot in place', () {
    final zoomed = tapZoomed(Matrix4.identity(), spot: spot, zoom: 2.5);

    expect(zoomed.getMaxScaleOnAxis(), 2.5);
    expect(MatrixUtils.transformPoint(zoomed, spot), spot);
  });

  test('zoomed in, it goes back to fit', () {
    final zoomed = Matrix4.identity()..scaleByDouble(1.2, 1.2, 1, 1);

    expect(tapZoomed(zoomed, spot: spot, zoom: 2.5), Matrix4.identity());
  });

  test('zoomed out past fit, it zooms in from fit', () {
    final out = Matrix4.identity()..scaleByDouble(0.8, 0.8, 1, 1);

    expect(
      tapZoomed(out, spot: spot, zoom: 2.5),
      tapZoomed(Matrix4.identity(), spot: spot, zoom: 2.5),
    );
  });
}
