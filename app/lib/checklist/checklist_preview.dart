import 'package:truce_core/truce_core.dart';

/// Card preview of a checklist: its first open items as `☐ text`;
/// `null` if [text] has no checkbox items.
String? checklistPreview(String text, {int maxItems = 6}) {
  final list = Checklist.parse(text);
  if (!list.hasItems) return null;
  final done = list.doneIds;
  return list.lines
      .where((line) => line.isItem && !done.contains(line.id))
      .take(maxItems)
      .map((line) => '${'  ' * list.depthOf(line)}☐ ${line.text}')
      .join('\n');
}
