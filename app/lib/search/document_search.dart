import '../documents/document.dart';

/// Documents whose title or text contains every word of [query], ignoring
/// case; the title may come from the file name. Title matches come
/// first; otherwise the order of [documents] is kept.
List<Document> searchNotes(List<Document> documents, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  if (words.isEmpty) return const [];
  final inTitle = <Document>[];
  final inText = <Document>[];
  for (final document in documents) {
    final title = document.title.toLowerCase();
    final text = '$title\n${document.file.text.toLowerCase()}';
    if (!words.every(text.contains)) continue;
    (words.any(title.contains) ? inTitle : inText).add(document);
  }
  return [...inTitle, ...inText];
}
