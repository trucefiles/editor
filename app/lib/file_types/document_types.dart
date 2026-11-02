import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_documents/truce_documents.dart';

import '../common/time_texts.dart';
import '../platform/platform_wiring.dart';
import 'calendar_document_type.dart';
import 'editable_type.dart';
import 'markdown_document_type.dart';
import 'plain_text_document_type.dart';

/// The document types the app handles: the one place that picks them,
/// at compile time; handed down from here to whatever needs them, down to
/// what the app may touch in a folder. A plain new document is a Markdown
/// note; calendars are made named.
final documentTypesProvider = Provider<DocumentTypes<EditableType>>((ref) {
  final system = PlatformDispatcher.instance;
  final calendars = CalendarDocumentType(
    times: TimeTexts(
      locale: system.locale.toLanguageTag(),
      use24Hour: system.alwaysUse24HourFormat,
    ),
    deviceZone: ref.watch(deviceZoneProvider),
  );
  return DocumentTypes(
    [const MarkdownDocumentType(), const PlainTextDocumentType(), calendars],
    newDocuments: [
      const NewDocument('Note', MarkdownDocumentType()),
      ...calendars.newDocuments,
    ],
  );
});
