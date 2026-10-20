import 'package:truce_core/truce_core.dart';

/// A shopping list with a checked item, a subitem and a text line.
const doc = '# Shopping\n- [ ] milk\n- [x] eggs\n  - [ ] large\n\nnote\n';

/// Id of the first line whose text is [text].
LineId idOf(MarkdownLines list, String text) =>
    list.lines.firstWhere((line) => line.text == text).id;
