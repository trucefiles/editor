import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_images/truce_images.dart';

void main() {
  /// Asks for one of [sources] on a button press; the answer lands in
  /// the returned list.
  Future<List<ImageSource?>> ask(
    WidgetTester tester,
    List<ImageSource> sources,
  ) async {
    final answers = <ImageSource?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                answers.add(await askImageSource(context, sources)),
            child: const Text('Add'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    return answers;
  }

  testWidgets('with one source, it is picked without asking', (tester) async {
    final answers = await ask(tester, [ImageSource.file]);

    expect(find.byType(BottomSheet), findsNothing);
    expect(answers, [ImageSource.file]);
  });

  testWidgets('with more, a sheet from the bottom asks which', (tester) async {
    final answers = await ask(tester, ImageSource.values);

    expect(find.byType(BottomSheet), findsOne);
    expect(find.text('Choose image'), findsOne);
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(answers, [ImageSource.camera]);
  });
}
