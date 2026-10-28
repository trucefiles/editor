import 'package:collection/collection.dart';

import 'rel_path.dart';

/// Which part of a base folder the app may see: all of it, or some of its
/// subfolders with everything inside them, now and later.
sealed class Selection {
  const Selection();

  /// A selection of [subfolders]; a subfolder inside another one adds
  /// nothing. None selects nothing.
  factory Selection.of(Iterable<RelPath> subfolders) {
    final all = subfolders.toSet();
    return Subfolders._({
      for (final subfolder in all)
        if (!all.any((other) => subfolder.isInside(other))) subfolder,
    });
  }

  /// Nothing: e.g. a base folder that no folder uses any more.
  static const nothing = Subfolders._({});

  /// Whether the file or folder at [path] lies inside the selection.
  bool covers(RelPath path);

  /// Whether a listing must walk [folder]: it lies inside the selection or
  /// on the way to a selected subfolder.
  bool reaches(RelPath folder);

  /// Whether this and [other] share a file or folder.
  bool overlaps(Selection other);

  /// Everything this or [other] selects.
  Selection union(Selection other);
}

/// The whole base folder.
final class WholeFolder extends Selection {
  const WholeFolder();

  @override
  bool covers(RelPath path) => true;

  @override
  bool reaches(RelPath folder) => true;

  @override
  bool overlaps(Selection other) => switch (other) {
    WholeFolder() => true,
    Subfolders(:final roots) => roots.isNotEmpty,
  };

  @override
  Selection union(Selection other) => this;

  @override
  bool operator ==(Object other) => other is WholeFolder;

  @override
  int get hashCode => (WholeFolder).hashCode;
}

/// Some subfolders of the base folder, none inside another.
final class Subfolders extends Selection {
  const Subfolders._(this.roots);

  /// The selected subfolders.
  final Set<RelPath> roots;

  /// The selected subfolder [path] lies in; `null` if none.
  RelPath? rootOf(RelPath path) =>
      roots.where((root) => path.isAtOrInside(root)).firstOrNull;

  @override
  bool covers(RelPath path) => rootOf(path) != null;

  @override
  bool reaches(RelPath folder) =>
      covers(folder) || roots.any((root) => root.isInside(folder));

  @override
  bool overlaps(Selection other) => switch (other) {
    WholeFolder() => other.overlaps(this),
    Subfolders(roots: final others) => roots.any(
      (root) => others.any(
        (other) =>
            root == other || root.isInside(other) || other.isInside(root),
      ),
    ),
  };

  @override
  Selection union(Selection other) => switch (other) {
    WholeFolder() => other,
    Subfolders(roots: final others) => Selection.of({...roots, ...others}),
  };

  @override
  bool operator ==(Object other) =>
      other is Subfolders &&
      const SetEquality<RelPath>().equals(other.roots, roots);

  @override
  int get hashCode => const SetEquality<RelPath>().hash(roots);
}
