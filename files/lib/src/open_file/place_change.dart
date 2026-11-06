import 'package:truce_core/truce_core.dart';

import '../file_place.dart';
import '../file_text.dart';
import '../move_failure.dart';
import '../new_file_name.dart';
import 'file_effects.dart';
import 'page_file.dart';

/// A place and name the user picked for a file, the name as typed;
/// [newSubfolder]: the place's subfolder is a new one, made with the
/// file's first write there.
typedef PickedPlace = ({FilePlace place, String name, bool newSubfolder});

/// How the name field starts when the user picks the open [file]'s place
/// and name, at [path] and with [firstLine] as its text's first line:
/// [name] is the name the file keeps, empty while a new file is named
/// after its text, so that it keeps following it; [hint] is the name an
/// empty field gives it.
({String name, String hint}) nameFieldOf(
  PageFile file,
  RelPath path,
  String firstLine,
) => (
  name: switch (file) {
    NewFile(:final name) => name ?? '',
    ExistingFile() => splitFileName(path.name).base,
  },
  hint: newFileName(firstLine, extension: ''),
);

/// What picking [picked] for the open [file] asks: [saved] is its file
/// as saved, `null` while its edits are not all in it; [firstLine] its
/// text's first line, which names it when the name is left empty.
sealed class PlaceChange {
  factory PlaceChange.of(
    PageFile file, {
    required FileText? saved,
    required String firstLine,
    required PickedPlace picked,
  }) {
    final name = picked.name.trim();
    if (file case NewFile(:final type, :final start)) {
      return NewPlace(
        NewFile(
          picked.place,
          type: type,
          start: start,
          name: name.isEmpty ? null : name,
          newSubfolder: picked.newSubfolder,
        ),
      );
    }
    if (saved == null) return const CantMove(MoveNotSaved());
    final title = name.isEmpty ? firstLine : name;
    if (picked.place.folder.id == saved.folder.id &&
        picked.place.subfolder == saved.path.parent &&
        isNamedAfter(saved.path.name, title)) {
      return const SamePlace();
    }
    return MoveTo((
      place: picked.place,
      title: title,
      newSubfolder: picked.newSubfolder,
    ));
  }
}

/// A new file: its file will go to [to].
final class NewPlace implements PlaceChange {
  const NewPlace(this.to);

  final NewFile to;
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
