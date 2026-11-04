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

  HomeSettings copyWith({int? recentCount, FileOrder? order, FileView? view}) =>
      HomeSettings(
        recentCount: recentCount ?? this.recentCount,
        recentDays: recentDays,
        order: order ?? this.order,
        view: view ?? this.view,
      );

  /// These settings with the age limit [days] (`null`: none).
  HomeSettings withRecentDays(int? days) => HomeSettings(
    recentCount: recentCount,
    recentDays: days,
    order: order,
    view: view,
  );

  Map<String, Object> toJson() => {
    'recentCount': recentCount,
    'recentDays': ?recentDays,
    'order': order.name,
    'view': view.name,
  };

  /// `null` if [json] is not a setting written by [toJson], or names a
  /// count or an age limit the user can't pick. Settings written before
  /// the age limit existed have none.
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
      other.view == view;

  @override
  int get hashCode => Object.hash(recentCount, recentDays, order, view);
}
