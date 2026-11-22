import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import 'image_file_support.dart';

/// Pictures as the app lists them: looked at, never edited, so they
/// count as edited only where the user asks; found by name only, never
/// read for search; two versions don't merge (the user picks one). A
/// card shows the picture itself, which its view package draws: this
/// side reads nothing for it.
base class ImageFileType implements ShownFileType {
  const ImageFileType();

  @override
  ImageFileSupport get support => const ImageFileSupport();

  @override
  String get name => 'Image';

  /// The user adds a picture they choose or take.
  @override
  List<NewFileKind> get newKinds => const [NewFileKind('Image')];

  /// Its view package draws the card.
  @override
  FileCardSummary? Function(FileBytes read)? get cardSummary => null;

  @override
  SearchText? Function(FileBytes read)? get searchText => null;

  @override
  bool get edited => false;

  @override
  FileMerge? get merge => null;
}
