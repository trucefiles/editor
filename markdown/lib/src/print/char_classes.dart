/// How the printer sees one character of text: the class CommonMark's
/// delimiter rules give the character it prints there, and whether it
/// prints as a character reference.
library;

import '../read/syntax/characters.dart';

/// The classes CommonMark's delimiter rules tell characters apart by.
enum CharClass {
  /// Unicode whitespace, a line break, or a text's start or end.
  whitespace,

  /// Unicode punctuation or symbols.
  punctuation,

  /// Anything else, e.g. letters and digits.
  other,
}

/// The class of the first character [char] prints as: an invisible
/// character prints as a reference, which starts and ends with
/// punctuation.
CharClass classOf(String char) => switch (char) {
  _ when isInvisible(char) => CharClass.punctuation,
  _ when isUnicodeWhitespace(char) => CharClass.whitespace,
  _ when isUnicodePunctuation(char) => CharClass.punctuation,
  _ => CharClass.other,
};

/// Whether [char] can't be seen in a file and so prints as a character
/// reference: controls, format characters, and spaces and separators
/// other than the plain space and tab.
bool isInvisible(String char) =>
    char != ' ' && char != '\t' && _invisible.hasMatch(char);

final _invisible = RegExp(r'^[\p{Cc}\p{Cf}\p{Z}]$', unicode: true);

/// A character standing for [charClass] in delimiter rules.
String representativeOf(CharClass charClass) => switch (charClass) {
  CharClass.whitespace => ' ',
  CharClass.punctuation => '!',
  CharClass.other => 'a',
};
