import 'package:truce_files/truce_files.dart';

import 'calendar_view_kind.dart';

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
/// the Calendar tab ([tab], by default [TabPlace.shown]) and the view its
/// page opens in, the one picked last there ([kind], by default the
/// month).
final class CalendarView {
  const CalendarView({
    this.tab = TabPlace.shown,
    this.kind = CalendarViewKind.month,
  });

  /// [view] as the calendar kept it; what it can't read is as never
  /// chosen. Kept before as `inTab: false`, which still reads as off.
  factory CalendarView.of(ViewSettings view) => CalendarView(
    tab: switch (view.json) {
      {'tab': 'hidden'} => TabPlace.hidden,
      {'tab': 'off'} || {'inTab': false} => TabPlace.off,
      _ => TabPlace.shown,
    },
    kind: switch (view.json) {
      {'kind': final String name} =>
        CalendarViewKind.values.asNameMap()[name] ?? CalendarViewKind.month,
      _ => CalendarViewKind.month,
    },
  );

  final TabPlace tab;
  final CalendarViewKind kind;

  /// This, in [tab] instead.
  CalendarView withTab(TabPlace tab) => CalendarView(tab: tab, kind: kind);

  /// This, opening in [kind] instead.
  CalendarView withKind(CalendarViewKind kind) =>
      CalendarView(tab: tab, kind: kind);

  /// As kept; nothing chosen is [ViewSettings.none].
  ViewSettings get settings => ViewSettings({
    if (tab != TabPlace.shown) 'tab': tab.name,
    if (kind != CalendarViewKind.month) 'kind': kind.name,
  });
}
