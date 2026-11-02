import 'package:flutter/foundation.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../text_zoom/text_zoom.dart';
import '../text_zoom/text_zoom_target.dart';

/// All settings of this device that are not about one file or the
/// folder list. Kept in app storage, never synced.
@immutable
final class DeviceSettings {
  const DeviceSettings({
    required this.documentTextZoom,
    required this.appTextZoom,
    required this.newFilePlace,
    required this.refresh,
    required this.addItemPlace,
    required this.closeToTray,
    required this.home,
    required this.calendarView,
  });

  /// What a device starts with.
  static const standard = DeviceSettings(
    documentTextZoom: TextZoom.normal,
    appTextZoom: TextZoom.normal,
    newFilePlace: null,
    refresh: RefreshSettings.standard,
    addItemPlace: AddItemPlace.top,
    closeToTray: true,
    home: HomeSettings.standard,
    calendarView: CalendarViewKind.month,
  );

  final TextZoom documentTextZoom;
  final TextZoom appTextZoom;

  /// Where new files go; `null` for the default (see
  /// `FileActions.defaultFolder`).
  final NewFilePlaceSetting? newFilePlace;

  final RefreshSettings refresh;

  /// Where a list's Add item button shows.
  final AddItemPlace addItemPlace;

  /// Keep running in the tray when the window closes.
  final bool closeToTray;

  final HomeSettings home;

  /// The view calendars open in: the one picked last.
  final CalendarViewKind calendarView;

  /// How large the text of [target] shows.
  TextZoom textZoomOf(TextZoomTarget target) => switch (target) {
    TextZoomTarget.documents => documentTextZoom,
    TextZoomTarget.app => appTextZoom,
  };

  /// These settings with [zoom] for [target].
  DeviceSettings withTextZoom(TextZoomTarget target, TextZoom zoom) =>
      switch (target) {
        TextZoomTarget.documents => copyWith(documentTextZoom: zoom),
        TextZoomTarget.app => copyWith(appTextZoom: zoom),
      };

  /// These settings with the given ones changed. [newFilePlace] gives the
  /// new place, which may be `null` for the default.
  DeviceSettings copyWith({
    TextZoom? documentTextZoom,
    TextZoom? appTextZoom,
    NewFilePlaceSetting? Function()? newFilePlace,
    RefreshSettings? refresh,
    AddItemPlace? addItemPlace,
    bool? closeToTray,
    HomeSettings? home,
    CalendarViewKind? calendarView,
  }) => DeviceSettings(
    documentTextZoom: documentTextZoom ?? this.documentTextZoom,
    appTextZoom: appTextZoom ?? this.appTextZoom,
    newFilePlace: newFilePlace != null ? newFilePlace() : this.newFilePlace,
    refresh: refresh ?? this.refresh,
    addItemPlace: addItemPlace ?? this.addItemPlace,
    closeToTray: closeToTray ?? this.closeToTray,
    home: home ?? this.home,
    calendarView: calendarView ?? this.calendarView,
  );

  Map<String, Object?> toJson() => {
    'documentTextZoom': documentTextZoom.toJson(),
    'appTextZoom': appTextZoom.toJson(),
    'newFilePlace': newFilePlaceToJson(newFilePlace),
    'refresh': refresh.toJson(),
    'addItemPlace': addItemPlace.name,
    'closeToTray': closeToTray,
    'home': home.toJson(),
    'calendarView': calendarView.name,
  };

  /// The settings [json] holds, each read on its own: one missing or not
  /// written by [toJson] takes its [standard] value, the others stay.
  static DeviceSettings fromJson(Object? json) {
    final fields = json is Map<String, Object?>
        ? json
        : const <String, Object?>{};
    return DeviceSettings(
      documentTextZoom:
          TextZoom.fromJson(fields['documentTextZoom']) ??
          standard.documentTextZoom,
      appTextZoom:
          TextZoom.fromJson(fields['appTextZoom']) ?? standard.appTextZoom,
      newFilePlace: newFilePlaceFromJson(fields['newFilePlace']),
      refresh: RefreshSettings.fromJson(fields['refresh']) ?? standard.refresh,
      addItemPlace:
          AddItemPlace.values.asNameMap()[fields['addItemPlace']] ??
          standard.addItemPlace,
      closeToTray: switch (fields['closeToTray']) {
        final bool closeToTray => closeToTray,
        _ => standard.closeToTray,
      },
      home: HomeSettings.fromJson(fields['home']) ?? standard.home,
      calendarView:
          CalendarViewKind.values.asNameMap()[fields['calendarView']] ??
          standard.calendarView,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceSettings &&
      other.documentTextZoom == documentTextZoom &&
      other.appTextZoom == appTextZoom &&
      other.newFilePlace == newFilePlace &&
      other.refresh == refresh &&
      other.addItemPlace == addItemPlace &&
      other.closeToTray == closeToTray &&
      other.home == home &&
      other.calendarView == calendarView;

  @override
  int get hashCode => Object.hash(
    documentTextZoom,
    appTextZoom,
    newFilePlace,
    refresh,
    addItemPlace,
    closeToTray,
    home,
    calendarView,
  );
}
