import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// What a document's type keeps of how the document shows on this device
/// (e.g. Markdown's edit mode). Only the type reads and writes it; the
/// app keeps it as is, as JSON.
@immutable
final class ViewSettings {
  const ViewSettings(this.json);

  /// Nothing kept yet.
  static const none = ViewSettings({});

  final Map<String, Object?> json;

  static const _equality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is ViewSettings && _equality.equals(other.json, json);

  @override
  int get hashCode => _equality.hash(json);
}
