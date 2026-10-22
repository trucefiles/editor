import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/text_size/note_text_size.dart';
import 'package:truce_editor/editor/text_size/ui/note_text_scale.dart';

void main() {
  /// How large [NoteTextScale] at [percent] shows 10 px text, under a
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
        child: NoteTextScale(
          size: NoteTextSize.closestTo(percent),
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
