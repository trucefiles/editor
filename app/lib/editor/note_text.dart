import 'package:flutter/foundation.dart';

/// The text of an open note, as the user edits it. Listeners hear of every
/// change to [text], also from elsewhere.
abstract interface class NoteText implements Listenable {
  String get text;

  void edit(String text);
}
