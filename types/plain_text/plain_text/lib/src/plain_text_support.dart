import 'package:truce_core/truce_core.dart';

/// Plain text documents.
const plainTextType = FileType('plain_text');

/// What the app knows of plain text files: `.txt`.
final class PlainTextSupport implements FileTypeSupport {
  const PlainTextSupport();

  @override
  FileType get type => plainTextType;

  @override
  Set<String> get extensions => const {'txt'};
}
