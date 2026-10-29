import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_documents/truce_documents.dart';

/// A document type as the app wires it: the type itself, and its editor
/// on the one text document page.
abstract interface class EditableType implements DocumentType {
  /// Opens the editor of a document of this type, starting at [start], on
  /// [page]: its part the page model drives, and the view the page shows
  /// of it.
  OpenedEditor openEditor(EditorStart start, EditorPage page);
}

/// An open document's editor: its [part] and the [view] of it.
typedef OpenedEditor = ({EditorPart part, EditorView view});
