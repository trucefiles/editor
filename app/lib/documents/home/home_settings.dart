import 'package:flutter/foundation.dart';

/// How All orders documents.
enum DocumentOrder {
  /// Newest first.
  time,

  /// By folder and subfolder, then by file name.
  name,
}

/// How All shows documents.
enum DocumentView { cards, list }

/// The home screen's settings, per device.
@immutable
final class HomeSettings {
  const HomeSettings({
    required this.recentCount,
    required this.order,
    required this.view,
  });

  /// The last 50 documents in Recent; All newest first, as cards.
  static const standard = HomeSettings(
    recentCount: 50,
    order: DocumentOrder.time,
    view: DocumentView.cards,
  );

  /// The numbers of documents Recent can show.
  static const recentCounts = [20, 50, 100, 200];

  /// How many documents Recent shows besides the pinned ones.
  final int recentCount;

  final DocumentOrder order;
  final DocumentView view;

  HomeSettings copyWith({
    int? recentCount,
    DocumentOrder? order,
    DocumentView? view,
  }) => HomeSettings(
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
        DocumentOrder.values.asNameMap()[order],
        DocumentView.values.asNameMap()[view],
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
