import 'dart:async';

import '../view_settings.dart';
import 'editor_part.dart';

/// An [EditorPart] whose file shows one way: to edit, or only to read
/// while it can't be edited here. A change to what its type keeps of how
/// the file shows ([viewChanged]) doesn't change how it shows.
abstract base class FixedViewEditorPart implements EditorPart {
  /// Only to read at first if [readOnly].
  FixedViewEditorPart({required this._readOnly});

  final _changes = StreamController<void>.broadcast(sync: true);

  bool _readOnly;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void showReadOnly({required bool readOnly}) {
    if (readOnly == _readOnly) return;
    _readOnly = readOnly;
    _changes.add(null);
  }

  @override
  bool get isEditing => !_readOnly;

  @override
  void viewChanged(ViewSettings view) {}

  @override
  void dispose() => unawaited(_changes.close());
}
