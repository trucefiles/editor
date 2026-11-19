import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_images/truce_images.dart';

import 'image_picking.dart';

/// What adding an image to a document needs: how pictures are picked,
/// where they are kept, and how a short hint shows.
typedef ImageAdding = ({
  ImagePicking picking,
  HostImages kept,
  void Function(String message) hint,
});

/// The Image button's flow: a picture picked, made ready away from the
/// screen's thread, kept in the folder, then [insert]ed as a link.
/// [busy] while it is made ready and kept; one at a time. Once
/// [dispose]d (its view gone), it stops at its next step: a picture not
/// kept yet never is; one kept already stays unused, for the cleanup.
final class ImageInsert extends ChangeNotifier {
  ImageInsert(this._adding, {required this.insert});

  /// Read at each insert: what the page gives now.
  final ImageAdding Function() _adding;

  /// Puts the link to the kept image in the document at the caret.
  final void Function(String link) insert;

  bool get busy => _busy;
  var _busy = false;
  var _disposed = false;

  Future<void> from(ImageSource source) async {
    if (_busy) return;
    final (:picking, :kept, :hint) = _adding();
    final bytes = await picking.pick(source);
    if (bytes == null || _disposed) return;
    _setBusy(true);
    try {
      final prepared = await prepareInBackground(bytes, picking.settings);
      if (_disposed) return;
      if (prepared == null) {
        return hint("That file isn't an image the app can show.");
      }
      final added = await kept.add(
        prepared.bytes,
        extension: prepared.kind.extension,
      );
      if (_disposed) return;
      switch (added) {
        case Ok(value: final link):
          insert(link);
        case Err():
          hint("Couldn't add the image: the folder can't be written now.");
      }
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool busy) {
    _busy = busy;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
