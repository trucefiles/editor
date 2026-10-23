import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';

void main() {
  /// How large [TextZoomScale] at [percent] shows 10 px text, under a
  /// system scaling of [system].
  Future<double> scaled(
    WidgetTester tester, {
    required int percent,
    double system = 1,
  }) async {
    late double size;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(system)),
        child: TextZoomScale(
          zoom: TextZoom.closestTo(percent),
          child: Builder(
            builder: (context) {
              size = MediaQuery.textScalerOf(context).scale(10);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return size;
  }

  testWidgets('scales notes text by the size', (tester) async {
    expect(await scaled(tester, percent: 150), 15);
    expect(await scaled(tester, percent: 80), 8);
  });

  testWidgets("scales on top of the system's own scaling", (tester) async {
    expect(await scaled(tester, percent: 150, system: 2), 30);
  });
}
