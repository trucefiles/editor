import '../notes/note.dart';

/// Notes whose title or text contains every word of [query], ignoring
/// case; the title may come from the file name. Title matches come
/// first; otherwise the order of [notes] is kept.
List<Note> searchNotes(List<Note> notes, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  if (words.isEmpty) return const [];
  final inTitle = <Note>[];
  final inText = <Note>[];
  for (final note in notes) {
    final title = note.title.toLowerCase();
    final text = '$title\n${note.file.text.toLowerCase()}';
    if (!words.every(text.contains)) continue;
    (words.any(title.contains) ? inTitle : inText).add(note);
  }
  return [...inTitle, ...inText];
}
