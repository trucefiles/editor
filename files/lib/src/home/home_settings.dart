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
  });

  /// The last 50 files in Recent; All newest first, as cards.
  static const standard = HomeSettings(
    recentCount: 50,
    order: FileOrder.time,
    view: FileView.cards,
  );

  /// The numbers of files Recent can show.
  static const recentCounts = [20, 50, 100, 200];

  /// How many files Recent shows besides the pinned ones.
  final int recentCount;

  final FileOrder order;
  final FileView view;

  HomeSettings copyWith({int? recentCount, FileOrder? order, FileView? view}) =>
      HomeSettings(
        recentCount: recentCount ?? this.recentCount,
        order: order ?? this.order,
        view: view ?? this.view,
      );

  Map<String, Object> toJson() => {
    'recentCount': recentCount,
    'order': order.name,
    'view': view.name,
  };

  /// `null` if [json] is not a setting written by [toJson], or names a
  /// count the user can't pick.
  static HomeSettings? fromJson(Object? json) => switch (json) {
    {
      'recentCount': final int recentCount,
      'order': final String order,
      'view': final String view,
    }
        when recentCounts.contains(recentCount) =>
      switch ((
        FileOrder.values.asNameMap()[order],
        FileView.values.asNameMap()[view],
      )) {
        (final order?, final view?) => HomeSettings(
          recentCount: recentCount,
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
      other.order == order &&
      other.view == view;

  @override
  int get hashCode => Object.hash(recentCount, order, view);
}
