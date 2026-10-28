import 'package:truce_core/truce_core.dart';

import 'plain_summary.dart';

/// Plain text documents.
const plainTextType = FileType('plain_text');

/// What the app knows of plain text files: `.txt`, and what lists show
/// of one ([PlainSummary]).
final class PlainTextSupport implements FileTypeSupport<PlainPreview> {
  const PlainTextSupport();

  @override
  FileType get type => plainTextType;

  @override
  Set<String> get extensions => const {'txt'};

  @override
  PlainSummary summary(String text, {required int maxLines}) =>
      PlainSummary(text, maxLines: maxLines);
}
