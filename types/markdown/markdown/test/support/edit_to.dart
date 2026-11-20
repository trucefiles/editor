import 'package:truce_text_editing/truce_text_editing.dart';

/// The edit that makes [after] of [before], as an editor sends it.
TextEdit editTo(String before, String after) =>
    TextEdit(before, textChange(before, after));
