import 'package:flutter/foundation.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_images/truce_images.dart';

import '../alerts/alert_style.dart';
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
    required this.tabCalendarView,
    required this.placeAboveText,
    required this.backupSpace,
    required this.alertStyle,
    required this.startAtLogin,
    required this.images,
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
    tabCalendarView: CalendarViewKind.month,
    placeAboveText: true,
    backupSpace: BackupSpace.standard,
    alertStyle: AlertStyle.notification,
    startAtLogin: false,
    images: ImageSettings.standard,
  );

  final TextZoom documentTextZoom;
  final TextZoom appTextZoom;

  /// Where new files go; `null` for the default (see
  /// `newFilePlaceIn`).
  final NewFilePlaceSetting? newFilePlace;

  final RefreshSettings refresh;

  /// Where a list's Add item button shows.
  final AddItemPlace addItemPlace;

  /// Keep running in the tray when the window closes.
  final bool closeToTray;

  final HomeSettings home;

  /// The view the Calendar tab opens in: the one picked last there.
  final CalendarViewKind tabCalendarView;

  /// Whether a file's location shows above its text; else it is only in
  /// the file's menu.
  final bool placeAboveText;

  /// How much space backups may take on this device.
  final BackupSpace backupSpace;

  /// How calendar alerts ring, where the device can tell apart.
  final AlertStyle alertStyle;

  /// Start in the tray when the user logs in, where the app has a tray.
  final bool startAtLogin;

  /// How pictures the user adds (to a document or as a file) are made
  /// ready.
  final ImageSettings images;

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
    CalendarViewKind? tabCalendarView,
    bool? placeAboveText,
    BackupSpace? backupSpace,
    AlertStyle? alertStyle,
    bool? startAtLogin,
    ImageSettings? images,
  }) => DeviceSettings(
    documentTextZoom: documentTextZoom ?? this.documentTextZoom,
    appTextZoom: appTextZoom ?? this.appTextZoom,
    newFilePlace: newFilePlace != null ? newFilePlace() : this.newFilePlace,
    refresh: refresh ?? this.refresh,
    addItemPlace: addItemPlace ?? this.addItemPlace,
    closeToTray: closeToTray ?? this.closeToTray,
    home: home ?? this.home,
    tabCalendarView: tabCalendarView ?? this.tabCalendarView,
    placeAboveText: placeAboveText ?? this.placeAboveText,
    backupSpace: backupSpace ?? this.backupSpace,
    alertStyle: alertStyle ?? this.alertStyle,
    startAtLogin: startAtLogin ?? this.startAtLogin,
    images: images ?? this.images,
  );

  Map<String, Object?> toJson() => {
    'documentTextZoom': documentTextZoom.toJson(),
    'appTextZoom': appTextZoom.toJson(),
    'newFilePlace': newFilePlaceToJson(newFilePlace),
    'refresh': refresh.toJson(),
    'addItemPlace': addItemPlace.name,
    'closeToTray': closeToTray,
    'home': home.toJson(),
    // Its name from when it was every calendar's view.
    'calendarView': tabCalendarView.name,
    'placeAboveText': placeAboveText,
    'backupSpace': backupSpace.name,
    'alertStyle': alertStyle.name,
    'startAtLogin': startAtLogin,
    'images': images.toJson(),
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
      tabCalendarView:
          CalendarViewKind.values.asNameMap()[fields['calendarView']] ??
          standard.tabCalendarView,
      placeAboveText: switch (fields['placeAboveText']) {
        final bool above => above,
        _ => standard.placeAboveText,
      },
      backupSpace:
          BackupSpace.values.asNameMap()[fields['backupSpace']] ??
          standard.backupSpace,
      alertStyle:
          AlertStyle.values.asNameMap()[fields['alertStyle']] ??
          standard.alertStyle,
      startAtLogin: switch (fields['startAtLogin']) {
        final bool start => start,
        _ => standard.startAtLogin,
      },
      images: ImageSettings.fromJson(fields['images']),
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
      other.tabCalendarView == tabCalendarView &&
      other.placeAboveText == placeAboveText &&
      other.backupSpace == backupSpace &&
      other.alertStyle == alertStyle &&
      other.startAtLogin == startAtLogin &&
      other.images == images;

  @override
  int get hashCode => Object.hash(
    documentTextZoom,
    appTextZoom,
    newFilePlace,
    refresh,
    addItemPlace,
    closeToTray,
    home,
    tabCalendarView,
    placeAboveText,
    backupSpace,
    alertStyle,
    startAtLogin,
    images,
  );
}
