import 'package:test/test.dart';
import 'package:truce_documents/truce_documents.dart';

void main() {
  test('reads back what it writes', () {
    const settings = HomeSettings(
      recentCount: 100,
      order: DocumentOrder.name,
      view: DocumentView.list,
    );

    expect(HomeSettings.fromJson(settings.toJson()), settings);
  });

  test('reads nothing from a count the user cannot pick or an unknown '
      'order', () {
    final json = HomeSettings.standard.toJson();

    expect(HomeSettings.fromJson({...json, 'recentCount': 7}), isNull);
    expect(HomeSettings.fromJson({...json, 'order': 'size'}), isNull);
    expect(HomeSettings.fromJson('not settings'), isNull);
  });

  test('shows the last 50 documents in Recent by default', () {
    expect(HomeSettings.standard.recentCount, 50);
  });
}
