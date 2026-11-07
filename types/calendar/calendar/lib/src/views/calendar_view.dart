import 'package:truce_files/truce_files.dart';

/// How a calendar shows in the Calendar tab on this device.
enum TabPlace {
  /// Its events show.
  shown,

  /// Its events don't show, but it can be turned on there.
  off,

  /// Left out of the tab; only listed to bring it back.
  hidden,
}

/// What a calendar keeps of how it shows on this device: its place in
/// the Calendar tab ([tab], by default [TabPlace.shown]).
final class CalendarView {
  const CalendarView({this.tab = TabPlace.shown});

  /// [view] as the calendar kept it; what it can't read is as never
  /// chosen. Kept before as `inTab: false`, which still reads as off.
  factory CalendarView.of(ViewSettings view) => CalendarView(
    tab: switch (view.json) {
      {'tab': 'hidden'} => TabPlace.hidden,
      {'tab': 'off'} || {'inTab': false} => TabPlace.off,
      _ => TabPlace.shown,
    },
  );

  final TabPlace tab;

  /// As kept; nothing chosen is [ViewSettings.none].
  ViewSettings get settings =>
      ViewSettings({if (tab != TabPlace.shown) 'tab': tab.name});
}
