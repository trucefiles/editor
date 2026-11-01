import 'package:truce_core/truce_core.dart';

import 'document_card_summary.dart';
import 'document_text.dart';

/// What one document type brings: its files ([support]), what cards show
/// of a text, and whether two texts of it merge on their own ([merge]).
abstract interface class DocumentType {
  FileTypeSupport<Object?> get support;

  /// The extension of a new file of this type, with its dot.
  String get newFileExtension;

  /// What cards and search show of [read], from its summary.
  DocumentCardSummary cardSummary(DocumentText read);

  /// How two texts of this type merge into one, e.g. a conflict copy into
  /// its file; `null` if they don't (the user compares and picks).
  TextMerge? get merge;
}
