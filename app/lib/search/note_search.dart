import '../notes/note.dart';

/// Notes whose text contains every word of [query], ignoring case. Title
/// matches come first; otherwise the order of [notes] is kept.
List<Note> searchNotes(List<Note> notes, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  if (words.isEmpty) return const [];
  final inTitle = <Note>[];
  final inText = <Note>[];
  for (final note in notes) {
    final text = note.file.text.toLowerCase();
    if (!words.every(text.contains)) continue;
    final title = note.title.toLowerCase();
    (words.any(title.contains) ? inTitle : inText).add(note);
  }
  return [...inTitle, ...inText];
}
