import 'dart:async';
import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart' show RelinkImages;
import 'package:truce_markdown_images/truce_markdown_images.dart';

import '../editor_gate.dart';
import '../visual/image_insert.dart';

/// Where a document is: its folder, and the subfolder it is in (`null`:
/// the top level).
typedef DocumentPlace = ({FolderId folder, RelPath? documentFolder});

/// The images of the Markdown document behind [_gate], at its place:
/// adding one there ([add]), and, as its place changes ([at]; e.g. a new
/// document's folder picked), its images going along into the new
/// folder first, then its links changing so each leads from there, as
/// one step of its editor. Each folder's images are [_storeOf]'s. One
/// step at a time, in order, so a link always leads from where the
/// document is.
final class ImagesAtPlace implements ImageKeeping {
  ImagesAtPlace(this._gate, this._storeOf, {required DocumentPlace place})
    : _asked = place,
      _linksFrom = place {
    unawaited(_gate.closed.then((_) => _closed = true));
  }

  final EditorGate _gate;
  final DocumentImageStore Function(FolderId folder) _storeOf;

  /// The place last told of ([at]).
  DocumentPlace _asked;

  /// The place the document's links lead from.
  DocumentPlace _linksFrom;

  /// The steps asked for, one after another: the last one asked for.
  Future<void> _turns = Future.value();

  var _closed = false;

  /// How a short hint shows, as the page last gave it.
  void Function(String message) _hint = (_) {};

  /// The document is at [path] in [folder] now; a hint shows by [hint].
  /// Its images follow if its folder or subfolder changed.
  void at(
    FolderId folder,
    RelPath path, {
    required void Function(String message) hint,
  }) {
    _hint = hint;
    final place = (folder: folder, documentFolder: path.parent);
    if (place == _asked) return;
    _asked = place;
    _inTurn(_follow);
  }

  @override
  Future<Result<void, StoreError>> add(
    Uint8List bytes, {
    required String extension,
    required void Function(String link) insert,
  }) => _inTurn(() async {
    final place = _linksFrom;
    final added = await _storeOf(place.folder)
        .add(bytes, extension: extension, documentFolder: place.documentFolder);
    if (added case Ok(value: final link) when !_closed) insert(link);
    return added.map((_) {});
  });

  Future<T> _inTurn<T>(Future<T> Function() step) {
    final done = _turns.then((_) => step());
    _turns = done.then<void>((_) {}, onError: (Object _) {});
    return done;
  }

  /// The images go along to the place last asked for, then the links
  /// change to lead from there. Images that can't go along keep their
  /// links, and a hint tells.
  Future<void> _follow() async {
    final (from, to) = (_linksFrom, _asked);
    if (to == _linksFrom || _closed) return;
    _linksFrom = to;
    final target = _storeOf(to.folder);
    if (to.folder != from.folder) {
      final names = ImageNames.ofLinks(_gate.state.content.imageLinks);
      if (await _storeOf(from.folder).copyInto(target, names) is Err) {
        _hint(
          "Couldn't take the images along: the folder can't be "
          'written now.',
        );
      }
    }
    if (ImageNames.linksAlike(from.documentFolder, to.documentFolder)) {
      return;
    }
    if (await target.relinkFrom(to.documentFolder) case Ok(value: final relink)
        when !_closed) {
      _gate.external(RelinkImages(relink));
    }
  }
}
