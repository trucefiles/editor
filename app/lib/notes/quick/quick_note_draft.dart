import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../../storage/json_file.dart';
import 'quick_note_place.dart';
import 'quick_note_place_store.dart';

/// A quick note not yet in any folder: its [text], and the [place] the
/// user picked for it, `null` while none is picked.
@immutable
final class QuickNoteDraft {
  const QuickNoteDraft({required this.text, this.place});

  final String text;
  final QuickNotePlace? place;

  @override
  bool operator ==(Object other) =>
      other is QuickNoteDraft && other.text == text && other.place == place;

  @override
  int get hashCode => Object.hash(text, place);
}

/// Keeps the one [QuickNoteDraft] in app storage, so a quick note survives
/// the app being ended before it goes into a folder. Per device and never
/// synced.
///
/// ```json
/// {"text": "Milk", "place": {"folder": "f1"}}
/// ```
final class QuickNoteDrafts {
  QuickNoteDrafts(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The kept draft; `null` if none, or unreadable.
  Future<QuickNoteDraft?> load() async => switch (await _file.read()) {
    Ok(value: {'text': final String text, 'place': final place}) =>
      QuickNoteDraft(text: text, place: QuickNotePlaceStore.decode(place)),
    Ok(value: {'text': final String text}) => QuickNoteDraft(text: text),
    _ => null,
  };

  /// Replaces the kept draft with [draft]; whether it was written.
  Future<bool> keep(QuickNoteDraft draft) async => await _file.write({
    'text': draft.text,
    if (draft.place case final place?)
      'place': QuickNotePlaceStore.encode(place),
  }) is Ok;

  /// Drops the draft, once it is in a folder or empty; whether it is gone.
  Future<bool> remove() async => await _file.delete() is Ok;
}
