import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

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
    this.uneditedLeftOut = const {},
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

  /// The folders whose files of types not edited in the app (e.g.
  /// pictures) stay out of Recently edited; every other folder's show
  /// there as if they were edited, so a new folder shows them.
  final Set<FolderId> uneditedLeftOut;

  /// Whether Recently edited shows [folder]'s files of types not edited
  /// in the app.
  bool showsUneditedOf(FolderId folder) => !uneditedLeftOut.contains(folder);

  /// These settings with [folder]'s files of types not edited in the app
  /// [shown] in Recently edited or not.
  HomeSettings withUneditedOf(FolderId folder, {required bool shown}) =>
      _withLeftOut({
        for (final id in uneditedLeftOut)
          if (id != folder) id,
        if (!shown) folder,
      });

  /// These settings with nothing kept for [folder], e.g. once it is
  /// removed.
  HomeSettings forgetting(FolderId folder) =>
      withUneditedOf(folder, shown: true);

  /// The oldest change Recently edited shows at [now]; `null`: any age.
  DateTime? recentSince(DateTime now) => switch (recentDays) {
    null => null,
    final days => now.subtract(Duration(days: days)),
  };

  HomeSettings copyWith({int? recentCount, FileOrder? order, FileView? view}) =>
      HomeSettings(
        recentCount: recentCount ?? this.recentCount,
        recentDays: recentDays,
        order: order ?? this.order,
        view: view ?? this.view,
        uneditedLeftOut: uneditedLeftOut,
      );

  /// These settings with the age limit [days] (`null`: none).
  HomeSettings withRecentDays(int? days) => HomeSettings(
    recentCount: recentCount,
    recentDays: days,
    order: order,
    view: view,
    uneditedLeftOut: uneditedLeftOut,
  );

  HomeSettings _withLeftOut(Set<FolderId> leftOut) => HomeSettings(
    recentCount: recentCount,
    recentDays: recentDays,
    order: order,
    view: view,
    uneditedLeftOut: Set.unmodifiable(leftOut),
  );

  Map<String, Object> toJson() => {
    'recentCount': recentCount,
    'recentDays': ?recentDays,
    'order': order.name,
    'view': view.name,
    if (uneditedLeftOut.isNotEmpty)
      'uneditedLeftOut': [
        for (final folder in uneditedLeftOut) [folder.plugin, folder.folder],
      ],
  };

  /// `null` if [json] is not a setting written by [toJson], or names a
  /// count or an age limit the user can't pick. Settings written before
  /// the age limit existed have none; folders left out that can't be
  /// read are dropped (none: every folder shows its unedited files).
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
            uneditedLeftOut: _foldersOf(map['uneditedLeftOut']),
          ),
        _ => null,
      },
    _ => null,
  };

  static Set<FolderId> _foldersOf(Object? json) => switch (json) {
    final List<Object?> folders => Set.unmodifiable({
      for (final folder in folders)
        if (folder case [final String plugin, final String id])
          ?FolderId.parse(plugin, id),
    }),
    _ => const {},
  };

  @override
  bool operator ==(Object other) =>
      other is HomeSettings &&
      other.recentCount == recentCount &&
      other.recentDays == recentDays &&
      other.order == order &&
      other.view == view &&
      const SetEquality<FolderId>().equals(
        other.uneditedLeftOut,
        uneditedLeftOut,
      );

  @override
  int get hashCode => Object.hash(
    recentCount,
    recentDays,
    order,
    view,
    const SetEquality<FolderId>().hash(uneditedLeftOut),
  );
}
