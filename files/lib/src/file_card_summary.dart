import 'package:meta/meta.dart';

import 'view_settings.dart';

/// What cards and search show of one version of a file: its title and
/// its preview, as the file's view settings on this device say. Worked
/// out by the file's type, from one read of the text; holds only the
/// strings shown, never the text.
@immutable
final class FileCardSummary {
  const FileCardSummary({
    required this.title,
    required this.preview,
    this.holdsUntil,
  });

  /// Most lines a preview holds.
  static const previewLines = 10;

  /// The text's own title, else the file name without its extension.
  final String title;

  /// The preview as the file's view settings say.
  final String Function(ViewSettings view) preview;

  /// When the preview may change though the text doesn't (e.g. a
  /// calendar's next events, once the first has passed); `null`: it
  /// holds as long as the text.
  final DateTime? holdsUntil;
}
