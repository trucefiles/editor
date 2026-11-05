import 'package:test/test.dart';
import 'package:truce_folders/truce_folders.dart';

void main() {
  test('is live, checking every 10 seconds, by default', () {
    expect(RefreshSettings.standard.mode, RefreshMode.live);
    expect(RefreshSettings.standard.interval, const Duration(seconds: 10));
  });

  test('reads back what it writes', () {
    const settings = RefreshSettings(
      mode: RefreshMode.periodic,
      interval: Duration(minutes: 1),
    );

    expect(RefreshSettings.fromJson(settings.toJson()), settings);
  });

  test('refuses unknown modes and intervals the user cannot pick', () {
    expect(
      RefreshSettings.fromJson({'mode': 'sometimes', 'intervalSeconds': 10}),
      isNull,
    );
    expect(
      RefreshSettings.fromJson({'mode': 'live', 'intervalSeconds': 0}),
      isNull,
    );
    expect(RefreshSettings.fromJson('live'), isNull);
  });

  test('only Manual lists the folders when a file closes', () {
    expect(
      {
        for (final mode in RefreshMode.values)
          mode: RefreshSettings.standard
              .copyWith(mode: mode)
              .listsWhenFileCloses,
      },
      {
        RefreshMode.live: false,
        RefreshMode.periodic: false,
        RefreshMode.manual: true,
      },
    );
  });
}
