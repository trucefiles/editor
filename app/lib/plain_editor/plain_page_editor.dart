import 'package:truce_core/truce_core.dart';
import 'package:truce_plain_text/truce_plain_text.dart';

/// The plain text editor owner [_owner] as the document page sees it
/// (core's editor contract).
final class PlainPageEditor implements PageEditor {
  PlainPageEditor(this._owner);

  final PlainOwner _owner;

  @override
  void send(EditorRequest input) => _owner.send(PlainRequest(input));

  @override
  EditorStatus get state => _owner.state.status;

  @override
  late final Stream<EditorStatus> changes = _owner.changes
      .map((state) => state.status)
      .distinct();

  @override
  Stream<EditorNotice> get events => _owner.events.map((event) => event.notice);

  @override
  Future<void> close() => _owner.close();
}
