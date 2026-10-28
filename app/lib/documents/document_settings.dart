import 'package:flutter/foundation.dart';

import 'view_settings.dart';

/// How this device shows one document: view settings, not properties of the
/// document, so they are kept per device and never synced.
@immutable
final class DocumentSettings {
  const DocumentSettings({this.pinned = false, this.view = ViewSettings.none});

  /// Nothing chosen yet.
  static const defaults = DocumentSettings();

  /// Shown before documents that are not pinned.
  final bool pinned;

  /// What the document's type keeps.
  final ViewSettings view;

  bool get isDefault => this == defaults;

  DocumentSettings withPinned({required bool pinned}) =>
      DocumentSettings(pinned: pinned, view: view);

  DocumentSettings withView(ViewSettings view) =>
      DocumentSettings(pinned: pinned, view: view);

  @override
  bool operator ==(Object other) =>
      other is DocumentSettings && other.pinned == pinned && other.view == view;

  @override
  int get hashCode => Object.hash(pinned, view);
}
