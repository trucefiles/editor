import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

import '../file_place.dart';
import '../new_file_name.dart';

/// A new file made whole by the user (e.g. a picture they chose), not
/// written yet: its [bytes] go to [place], named [name] (with its
/// extension; a number is added if it is taken then). [newSubfolder]:
/// [place]'s subfolder is a new one the user asked for, made right
/// before the file.
@immutable
final class NewShownFile {
  const NewShownFile(
    this.place, {
    required this.name,
    required this.bytes,
    this.newSubfolder = false,
  });

  final FilePlace place;
  final String name;
  final Uint8List bytes;
  final bool newSubfolder;

  /// Where it goes in its folder, as the name would be written now.
  RelPath get path {
    final (:base, :extension) = splitFileName(name);
    final file = newFileName(base, extension: extension);
    return place.subfolder?.child(file) ?? RelPath.parse(file)!;
  }

  /// The name without its extension, as the user edits it.
  String get title => splitFileName(name).base;

  /// It, going to [place] instead, titled [title] (its extension
  /// kept); [newSubfolder] as for a new one.
  NewShownFile at(
    FilePlace place, {
    required String title,
    bool newSubfolder = false,
  }) => NewShownFile(
    place,
    name: '$title${splitFileName(name).extension}',
    bytes: bytes,
    newSubfolder: newSubfolder,
  );
}
