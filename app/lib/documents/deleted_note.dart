import 'package:truce_core/truce_core.dart';

import 'document.dart';
import 'document_settings.dart';

/// A deleted document with its text, mark and settings, enough to write it
/// back as it was.
typedef DeletedNote = ({
  Document document,
  String text,
  DocumentMark mark,
  DocumentSettings settings,
});
