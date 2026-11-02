import 'package:meta/meta.dart';

import 'view_settings.dart';

/// How this device shows one file: view settings, not properties of the
/// file, so they are kept per device and never synced.
@immutable
final class FileSettings {
  const FileSettings({this.pinned = false, this.view = ViewSettings.none});

  /// Nothing chosen yet.
  static const defaults = FileSettings();

  /// Shown before files that are not pinned.
  final bool pinned;

  /// What the file's type keeps.
  final ViewSettings view;

  bool get isDefault => this == defaults;

  FileSettings withPinned({required bool pinned}) =>
      FileSettings(pinned: pinned, view: view);

  FileSettings withView(ViewSettings view) =>
      FileSettings(pinned: pinned, view: view);

  @override
  bool operator ==(Object other) =>
      other is FileSettings && other.pinned == pinned && other.view == view;

  @override
  int get hashCode => Object.hash(pinned, view);
}
