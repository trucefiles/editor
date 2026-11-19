import 'dart:math';

import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart'
    show MarkdownSupport, imageLinksOf, markdownType;

/// The one rule for where the app keeps document images and how it names
/// them: `document-images/img-<id>.<extension>` at a folder's root, the
/// id 16 random hex digits. A link whose last part is such a name may be
/// one of ours, wherever it points.
abstract final class ImageNames {
  /// The folder that holds them, at the root.
  static final folder = RelPath.parse('document-images')!;

  /// Whether [path] is the folder or lies inside it: the files the app
  /// keeps apart from the documents.
  static bool isKept(RelPath path) => path.isAtOrInside(folder);

  static final _name = RegExp(r'^img-[0-9a-f]{16}\.(jpg|png|gif|webp|bmp)$');

  static final _random = Random.secure();

  /// A new name for an image with [extension] (without its dot).
  static String newName(String extension) {
    final id = [for (var i = 0; i < 8; i++) _random.nextInt(256)]
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'img-$id.$extension';
  }

  /// The name [link] ends in, if it is one of ours; `null` for any other
  /// link (one with a scheme, a query or another name).
  static String? nameIn(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.hasScheme || uri.hasQuery || uri.hasFragment) {
      return null;
    }
    final name = uri.pathSegments.lastOrNull;
    return name != null && _name.hasMatch(name) ? name : null;
  }

  /// The names of ours the images of the document [text] lead to, as
  /// read.
  static Set<String> linkedBy(String text) => ofLinks(imageLinksOf(text));

  /// The names of ours [links] lead to.
  static Set<String> ofLinks(Iterable<String> links) => {
    for (final link in links) ?nameIn(link),
  };

  /// Whether [path] is a document whose images are ours to keep.
  static bool isDocument(RelPath path) =>
      _documents.detect(path) == markdownType;

  static final _documents = ExtensionFileTypeDetector.of([
    const MarkdownSupport(),
  ]);

  /// Where the image [link] names is kept, wherever it points; `null`
  /// for a link whose name isn't ours. It may not be there.
  static RelPath? keptAt(String link) => switch (nameIn(link)) {
    final name? => pathOf(name),
    null => null,
  };

  /// Where the image [name] is kept.
  static RelPath pathOf(String name) => folder.child(name)!;

  /// Whether links to images from documents in [one] and [other]
  /// (`null`: the top level) read alike: the store is at the root, so
  /// only their depth counts.
  static bool linksAlike(RelPath? one, RelPath? other) =>
      _depth(one) == _depth(other);

  static int _depth(RelPath? folder) =>
      folder == null ? 0 : folder.folders.length + 1;

  /// The link to the image [name] from a document in [documentFolder]
  /// (`null`: the top level).
  static String linkFrom(RelPath? documentFolder, String name) {
    final up = documentFolder == null
        ? ''
        : '../' * (documentFolder.folders.length + 1);
    return '$up${pathOf(name).value}';
  }
}
