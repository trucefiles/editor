import 'package:truce_file_page/truce_file_page.dart';

import 'add_item_place/add_item_place.dart';
import 'ui/document_image.dart';

/// What the page gives a text editor's view, besides what every view
/// gets: where lists get Add item buttons ([addItems]), how a web or mail
/// link opens ([openLink]), and the document's [images].
final class TextHost extends EditorHost {
  const TextHost({
    required super.kept,
    required super.hint,
    required this.addItems,
    required this.openLink,
    required this.images,
  });

  final AddItemPlace addItems;
  final Future<void> Function(Uri link) openLink;
  final DocumentImages images;
}
