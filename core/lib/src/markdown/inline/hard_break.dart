/// Whether the backslash at [index] in [text] is no escaped one: an odd
/// run of backslashes ends there. Before a line break, it is a hard break.
bool breaksAt(String text, int index) =>
    RegExp(r'\\*$').stringMatch(text.substring(0, index + 1))!.length.isOdd;
