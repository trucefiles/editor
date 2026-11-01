import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_documents/truce_documents.dart';

import 'document_card.dart';
import 'document_grid.dart';
import 'listed_document.dart';
import 'pin_or_color_sheet.dart';

/// The card of a listed [document] in a document grid; opens it on tap.
class ListedDocumentCard extends ConsumerWidget {
  const ListedDocumentCard(this.document, {super.key});

  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:preview, :mark, :settings, :hasConflict) = watchListed(
      ref,
      document,
    );
    return gridCard(
      ready: preview is! PreviewReading,
      DocumentCard(
        document,
        preview: preview,
        mark: mark,
        settings: settings,
        hasConflict: hasConflict,
        onTap: () => openDocument(context, ref, document),
        onMark: () => editPinOrColor(context, ref, document),
      ),
    );
  }
}
