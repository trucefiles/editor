import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_images/truce_images.dart';

/// Keeping a picture for a document and linking it there.
abstract interface class ImageKeeping {
  /// Keeps [bytes], an image with [extension] (without its dot), for the
  /// document, and puts the link to it in its text by [insert], leading
  /// from where the document is then. Fails if the folder can't be
  /// written (e.g. it can't be reached).
  Future<Result<void, StoreError>> add(
    Uint8List bytes, {
    required String extension,
    required void Function(String link) insert,
  });
}

/// What adding an image to a document needs: how pictures are picked,
/// how they are kept, and how a short hint shows.
typedef ImageAdding = ({
  ImagePicking picking,
  ImageKeeping kept,
  void Function(String message) hint,
});

/// Where an [ImageInsert] is: [idle], [picking] (a dialog or camera
/// open), [preparing] (made ready and kept), or [closed] (its view gone).
enum _Step { idle, picking, preparing, closed }

/// The Image button's flow: a picture picked, made ready away from the
/// screen's thread, kept in the folder and [insert]ed as a link. One at a
/// time, from the click on; [busy] while it is made ready and kept. Once
/// [dispose]d (its view gone), it stops at its next step: a picture not
/// kept yet never is; one kept as the view went stays unlinked, for the
/// cleanup.
final class ImageInsert extends ChangeNotifier {
  ImageInsert(this._adding, {required this.insert});

  /// Read at each insert: what the page gives now.
  final ImageAdding Function() _adding;

  /// Puts the link to the kept image in the document at the caret.
  final void Function(String link) insert;

  bool get busy => _step == _Step.preparing;
  var _step = _Step.idle;
  bool get _closed => _step == _Step.closed;

  Future<void> from(ImageSource source) async {
    if (_step != _Step.idle) return;
    _to(_Step.picking);
    try {
      await _add(source);
    } finally {
      _to(_Step.idle);
    }
  }

  Future<void> _add(ImageSource source) async {
    final (:picking, :kept, :hint) = _adding();
    final picked = await picking.pick(source);
    if (picked == null || _closed) return;
    _to(_Step.preparing);
    final prepared = await prepareInBackground(picked.bytes, picking.settings);
    if (_closed) return;
    if (prepared == null) {
      return hint("That file isn't an image the app can show.");
    }
    final added = await kept.add(
      prepared.bytes,
      extension: prepared.kind.extension,
      insert: (link) {
        if (!_closed) insert(link);
      },
    );
    if (added is Err && !_closed) {
      hint("Couldn't add the image: the folder can't be written now.");
    }
  }

  /// Goes to [step], telling listeners when [busy] changes; never out of
  /// closed.
  void _to(_Step step) {
    if (_closed) return;
    final wasBusy = busy;
    _step = step;
    if (busy != wasBusy) notifyListeners();
  }

  @override
  void dispose() {
    _step = _Step.closed;
    super.dispose();
  }
}
