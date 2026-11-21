import 'file_place.dart';
import 'listed_file.dart';
import 'move_failure.dart';
import 'new_file_name.dart';

/// A place and name the user picked for a file, the name as typed;
/// [newSubfolder]: the place's subfolder is a new one, made with the
/// file's first write there.
typedef PickedPlace = ({FilePlace place, String name, bool newSubfolder});

/// Where the user moves a file: to [place], named after [title];
/// [newSubfolder]: [place]'s subfolder is a new one to make.
typedef MoveTarget = ({FilePlace place, String title, bool newSubfolder});

/// What picking a place and name for an open file asks.
sealed class PlaceChange {
  /// What [picked] asks of an open file: a new one ([isNew]) only
  /// changes where it goes; one with a file moves from where [saved]
  /// is, `null` while its edits are not all in it. An empty name keeps
  /// the file named after [unnamed].
  factory PlaceChange.of(
    PickedPlace picked, {
    required bool isNew,
    required ListedFile? saved,
    required String unnamed,
  }) {
    final name = picked.name.trim();
    if (isNew) {
      return NewPlace(
        picked.place,
        name: name.isEmpty ? null : name,
        newSubfolder: picked.newSubfolder,
      );
    }
    if (saved == null) return const CantMove(MoveNotSaved());
    final title = name.isEmpty ? unnamed : name;
    // A typed name is the name exactly, as a file name can hold it (e.g.
    // without a `?`); only a name left to follow [unnamed] may carry the
    // number added when it was taken.
    final named = name.isEmpty
        ? isNamedAfter(saved.path.name, unnamed)
        : splitFileName(saved.path.name).base == fileBaseName(name);
    if (picked.place.folder.id == saved.folder.id &&
        picked.place.subfolder == saved.path.parent &&
        named) {
      return const SamePlace();
    }
    return MoveTo((
      place: picked.place,
      title: title,
      newSubfolder: picked.newSubfolder,
    ));
  }
}

/// A new file: it will go to [place], named [name] (`null`: named as
/// before the user gave one); [newSubfolder] as in [PickedPlace].
final class NewPlace implements PlaceChange {
  const NewPlace(this.place, {required this.name, required this.newSubfolder});

  final FilePlace place;
  final String? name;
  final bool newSubfolder;
}

/// The file is there already, so nothing to do.
final class SamePlace implements PlaceChange {
  const SamePlace();
}

/// The file can't move now, for [failure].
final class CantMove implements PlaceChange {
  const CantMove(this.failure);

  final MoveFailure failure;
}

/// The file moves or is renamed [to].
final class MoveTo implements PlaceChange {
  const MoveTo(this.to);

  final MoveTarget to;
}
