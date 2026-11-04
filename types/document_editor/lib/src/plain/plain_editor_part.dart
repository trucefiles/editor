import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

/// A plain text document's part of the document page: its editor owner,
/// edited line by line as written, or only read while it can't be
/// edited. Keeps nothing of how the document shows.
final class PlainEditorPart extends FixedViewEditorPart {
  PlainEditorPart(EditorStart start)
    : owner = plainOwner(start.text, version: start.version),
      super(readOnly: start.readOnly);

  /// The editor owner.
  final PlainOwner owner;

  /// [owner] as the document page sees it (core's editor contract).
  @override
  late final PageEditor editor = OwnerView(
    owner,
    input: PlainRequest.new,
    state: (state) => state.status,
    event: (event) => event.notice,
  );
}
