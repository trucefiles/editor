import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'file_place.dart';

/// Why a file arrives at a place.
enum ArrivalBy {
  /// The user moves it.
  move,

  /// A past version of it comes back: its delete undone, a backup
  /// restored.
  restore,
}

/// A file about to be written at a place: [bytes], the file at [from] in
/// [folder], go to [to], [by] a move or a restore.
typedef Arrival = ({
  Uint8List bytes,
  Folder folder,
  RelPath from,
  FilePlace to,
  ArrivalBy by,
});

/// What one file type does as one of its files arrives at a place, e.g.
/// take along or bring back files it keeps beside them. Handed in from
/// above, per type; a type without one has its files written as they
/// are.
abstract interface class FileArrival {
  /// The bytes to write for [arrival] instead of its own; `null` to write
  /// them as they are. Fails if the file can't arrive as it must.
  Future<Result<Uint8List?, StoreError>> arrive(Arrival arrival);
}

/// The file types' [FileArrival]s, by type: the one rule for how a file
/// arrives at a place.
final class FileArrivals {
  const FileArrivals(this._detector, [this._byType = const {}]);

  final FileTypeDetector _detector;
  final Map<FileType, FileArrival> _byType;

  /// The bytes to write as [bytes], the file at [from] in [folder],
  /// move to [to], as its type's [FileArrival] says; `null` if it moves
  /// as it is. Fails if its type's step fails: the file then stays.
  Future<Result<Uint8List?, StoreError>> moved(
    Uint8List bytes, {
    required Folder folder,
    required RelPath from,
    required FilePlace to,
  }) => _arrive((
    bytes: bytes,
    folder: folder,
    from: from,
    to: to,
    by: ArrivalBy.move,
  ));

  /// The bytes to write as [bytes], a past version of the file at [from]
  /// in [folder], are restored at [to] (by default its own place), as its
  /// type's [FileArrival] says: [bytes] themselves if it has nothing to
  /// change. Best effort: a restore never waits on a failed step.
  Future<Uint8List> restored(
    Uint8List bytes, {
    required Folder folder,
    required RelPath from,
    FilePlace? to,
  }) async => switch (await _arrive((
    bytes: bytes,
    folder: folder,
    from: from,
    to: to ?? (folder: folder, subfolder: from.parent),
    by: ArrivalBy.restore,
  ))) {
    Ok(value: final arrived?) => arrived,
    Ok(value: null) || Err() => bytes,
  };

  /// The bytes its type's [FileArrival] gives for [arrival]; `null` for
  /// its own bytes, and for a type without one.
  Future<Result<Uint8List?, StoreError>> _arrive(Arrival arrival) async =>
      switch (_detector.detect(arrival.from)) {
        final type? => await _byType[type]?.arrive(arrival) ?? const Ok(null),
        null => const Ok(null),
      };
}
