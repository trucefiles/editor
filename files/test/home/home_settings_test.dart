import 'package:test/test.dart';
import 'package:truce_files/truce_files.dart';

void main() {
  test('reads back what it writes', () {
    const settings = HomeSettings(
      recentCount: 100,
      recentDays: 10,
      order: FileOrder.name,
      view: FileView.list,
    );

    expect(HomeSettings.fromJson(settings.toJson()), settings);
  });

  test('reads nothing from a count the user cannot pick or an unknown '
      'order', () {
    final json = HomeSettings.standard.toJson();

    expect(HomeSettings.fromJson({...json, 'recentCount': 7}), isNull);
    expect(HomeSettings.fromJson({...json, 'recentDays': 7}), isNull);
    expect(HomeSettings.fromJson({...json, 'order': 'size'}), isNull);
    expect(HomeSettings.fromJson('not settings'), isNull);
  });

  test('reads settings written before the age limit, with none', () {
    expect(
      HomeSettings.fromJson({
        'recentCount': 20,
        'order': 'time',
        'view': 'cards',
      }),
      HomeSettings.standard.copyWith(recentCount: 20),
    );
  });

  test('changes the age limit, and keeps it on other changes', () {
    final limited = HomeSettings.standard.withRecentDays(5);

    expect(limited.recentDays, 5);
    expect(limited.copyWith(view: FileView.list).recentDays, 5);
    expect(limited.withRecentDays(null).recentDays, isNull);
  });

  test('shows the last 50 documents of any age by default', () {
    expect(HomeSettings.standard.recentCount, 50);
    expect(HomeSettings.standard.recentDays, isNull);
  });
}
