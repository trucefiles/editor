/// Plain text documents for Truce: the first line names one, and the
/// editor edits the text as a whole.
///
/// Pure Dart, no UI; `core` and `files` know nothing of it. What the
/// app uses is exported here: the type as the app shows it
/// ([PlainTextFileType]), what lists show of a text ([PlainTextSupport])
/// and the editor's owner ([PlainOwner]).
library;

export 'src/owner/plain_owner.dart';
export 'src/plain_summary.dart';
export 'src/plain_text_file_type.dart';
export 'src/plain_text_support.dart';
