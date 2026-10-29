import 'document.dart';
import 'document_settings.dart';

/// Where each document's settings on this device are kept: the document
/// steps read, change and forget them as documents move or go.
abstract interface class DocumentSettingsKeeper {
  /// The settings of [document]; the defaults if none or not loaded yet.
  DocumentSettings settingsOf(DocumentKey document);

  /// Changes the settings of [document] with [change], starting from the
  /// settings the change before left.
  Future<void> edit(
    DocumentKey document,
    DocumentSettings Function(DocumentSettings settings) change,
  );

  /// Forgets the settings of [document], e.g. as the user deletes it.
  Future<void> forget(DocumentKey document);
}
