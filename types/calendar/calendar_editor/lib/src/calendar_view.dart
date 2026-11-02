import 'package:truce_files/truce_files.dart';

/// What a calendar keeps of how it shows on this device: whether the
/// Calendar tab shows its events ([inTab], by default it does).
final class CalendarView {
  const CalendarView({this.inTab = true});

  /// [view] as the calendar kept it; what it can't read is as never
  /// chosen.
  factory CalendarView.of(ViewSettings view) =>
      CalendarView(inTab: view.json['inTab'] != false);

  final bool inTab;

  /// As kept; nothing chosen is [ViewSettings.none].
  ViewSettings get settings => ViewSettings({if (!inTab) 'inTab': false});
}
