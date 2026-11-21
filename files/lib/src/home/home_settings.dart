import 'package:meta/meta.dart';

/// How All orders files.
enum FileOrder {
  /// Newest first.
  time,

  /// By folder and subfolder, then by file name.
  name,
}

/// How All shows files.
enum FileView { cards, list }

/// The home screen's settings, per device.
@immutable
final class HomeSettings {
  const HomeSettings({
    required this.recentCount,
    required this.order,
    required this.view,
    this.recentDays,
    this.uneditedInRecent = false,
  });

  /// The last 50 files of any age in Recently edited; All newest first,
  /// as cards.
  static const standard = HomeSettings(
    recentCount: 50,
    order: FileOrder.time,
    view: FileView.cards,
  );

  /// The numbers of files Recently edited can show.
  static const recentCounts = [20, 50, 100, 200];

  /// The age limits, in days, Recently edited can have.
  static const recentDayLimits = [2, 5, 10, 30];

  /// How many files Recently edited shows at most.
  final int recentCount;

  /// Recently edited shows only files changed in the last this many
  /// days; `null`: of any age.
  final int? recentDays;

  final FileOrder order;
  final FileView view;

  /// Whether Recently edited also shows files of types not edited in the
  /// app (e.g. pictures), as if they were.
  final bool uneditedInRecent;

  /// The oldest change Recently edited shows at [now]; `null`: any age.
  DateTime? recentSince(DateTime now) => switch (recentDays) {
    null => null,
    final days => now.subtract(Duration(days: days)),
  };

  HomeSettings copyWith({
    int? recentCount,
    FileOrder? order,
    FileView? view,
    bool? uneditedInRecent,
  }) => HomeSettings(
    recentCount: recentCount ?? this.recentCount,
    recentDays: recentDays,
    order: order ?? this.order,
    view: view ?? this.view,
    uneditedInRecent: uneditedInRecent ?? this.uneditedInRecent,
  );

  /// These settings with the age limit [days] (`null`: none).
  HomeSettings withRecentDays(int? days) => HomeSettings(
    recentCount: recentCount,
    recentDays: days,
    order: order,
    view: view,
    uneditedInRecent: uneditedInRecent,
  );

  Map<String, Object> toJson() => {
    'recentCount': recentCount,
    'recentDays': ?recentDays,
    'order': order.name,
    'view': view.name,
    if (uneditedInRecent) 'uneditedInRecent': true,
  };

  /// `null` if [json] is not a setting written by [toJson], or names a
  /// count or an age limit the user can't pick. Settings written before
  /// the age limit existed have none; anything but `true` for unedited
  /// files in Recently edited reads as its default.
  static HomeSettings? fromJson(Object? json) => switch (json) {
    {
              'recentCount': final int recentCount,
              'order': final String order,
              'view': final String view,
            } &&
            final Map<Object?, Object?> map
        when recentCounts.contains(recentCount) =>
      switch ((
        FileOrder.values.asNameMap()[order],
        FileView.values.asNameMap()[view],
        map['recentDays'],
      )) {
        (final order?, final view?, final int? days)
            when days == null || recentDayLimits.contains(days) =>
          HomeSettings(
            recentCount: recentCount,
            recentDays: days,
            order: order,
            view: view,
            uneditedInRecent: map['uneditedInRecent'] == true,
          ),
        _ => null,
      },
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeSettings &&
      other.recentCount == recentCount &&
      other.recentDays == recentDays &&
      other.order == order &&
      other.view == view &&
      other.uneditedInRecent == uneditedInRecent;

  @override
  int get hashCode =>
      Object.hash(recentCount, recentDays, order, view, uneditedInRecent);
}
