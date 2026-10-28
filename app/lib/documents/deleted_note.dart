import 'package:truce_core/truce_core.dart';

import 'document_settings.dart';
import 'document_text.dart';

/// A deleted document as last read, its text, mark and settings: enough
/// to write it back as it was.
typedef DeletedNote = ({
  DocumentText document,
  String text,
  DocumentMark mark,
  DocumentSettings settings,
});
