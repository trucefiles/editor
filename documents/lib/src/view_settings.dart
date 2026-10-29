import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// What a document's type keeps of how the document shows on this device
/// (e.g. Markdown's edit mode). Only the type reads and writes it; the
/// app keeps it as is, as JSON.
@immutable
final class ViewSettings {
  /// Holds a copy of [json] that can't be changed.
  ViewSettings(Map<String, Object?> json) : json = Map.unmodifiable(json);

  const ViewSettings._none() : json = const {};

  /// Nothing kept yet.
  static const none = ViewSettings._none();

  final Map<String, Object?> json;

  static const _equality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is ViewSettings && _equality.equals(other.json, json);

  @override
  int get hashCode => _equality.hash(json);
}
