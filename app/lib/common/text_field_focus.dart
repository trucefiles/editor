import 'package:flutter/widgets.dart';

/// Whether a text field (e.g. a name in a page's title) has the keyboard
/// focus: keys it answers itself, such as Ctrl+Z for its own undo, are
/// then its, not the screen's.
bool textFieldHasFocus() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>() !=
    null;
