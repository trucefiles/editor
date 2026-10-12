import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/app.dart';
import 'package:truce_editor/platform/app_storage.dart';

import 'support.dart';

void main() {
  testWidgets('asks for a folder on first start', (tester) async {
    final storage = AppStorage(tempFolder().path);

    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [appStorageProvider.overrideWithValue(storage)],
          child: const TruceApp(),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('Add folder'), findsOneWidget);
  });
}
