import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/app.dart';

void main() {
  testWidgets('shows the app title', (tester) async {
    await tester.pumpWidget(const TruceApp());

    expect(find.text(TruceApp.title), findsOneWidget);
  });
}
