import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import 'plain_summary.dart';
import 'plain_text_support.dart';

/// Plain text documents, as the app shows them: the first line names
/// one; search reads the whole text; two texts don't merge (the user
/// picks one). Its editor package adds how a file of it opens.
base class PlainTextFileType implements ShownFileType {
  const PlainTextFileType();

  @override
  PlainTextSupport get support => const PlainTextSupport();

  @override
  String get name => 'Plain text';

  @override
  TextFile get newFile => const TextFile.empty();

  /// The whole text.
  @override
  String searchText(FileText read) => read.text;

  @override
  FileCardSummary cardSummary(FileText read) {
    final preview = read.summary.preview(const PlainPreview());
    return FileCardSummary(
      title: titleOf(read.summary, read.path),
      preview: (_) => preview,
    );
  }

  /// Texts are compared and picked by the user.
  @override
  TextMerge? get merge => null;
}
