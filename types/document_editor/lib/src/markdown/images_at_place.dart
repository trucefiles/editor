import 'dart:async';

import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart' show RelinkImages;
import 'package:truce_markdown_images/truce_markdown_images.dart';

import '../editor_gate.dart';
import '../visual/image_insert.dart';

/// The images of the Markdown document behind [_gate], at its place:
/// adding one there ([add]), and, as its place changes ([at]; e.g. a new
/// document's folder picked), its images going along into the new
/// folder first, then its links changing so each leads from there, as
/// one step of its editor. Each folder's images are [_storeOf]'s. One
/// step at a time, in order, so a link always leads from where its
/// images are. A new document's place changes only once its images went
/// along (as for a move); this copies those not there yet, e.g. one
/// added meanwhile.
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

  /// The place the document's links lead from: where its images are.
  DocumentPlace _linksFrom;

  /// The steps asked for, one after another: the last one asked for.
  Future<void> _turns = Future.value();

  var _closed = false;

  /// How a short hint shows, as the page last gave it.
  void Function(String message) _hint = (_) {};

  /// The document is at [path] in [folder] now; a hint shows by [hint].
  /// Its images follow if its folder or subfolder changed; done once
  /// they did or couldn't.
  Future<void> at(
    FolderId folder,
    RelPath path, {
    required void Function(String message) hint,
  }) {
    _hint = hint;
    final place = (folder: folder, documentFolder: path.parent);
    if (place == _asked) return Future.value();
    _asked = place;
    return _inTurn(_follow);
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
  /// change to lead from there (see [imagesFollow]). If the images can't
  /// go along, the links stay as they are, and a hint tells.
  Future<void> _follow() async {
    final (from, to) = (_linksFrom, _asked);
    if (to == from || _closed) return;
    final followed = await imagesFollow(
      ImageNames.ofLinks(_gate.state.content.imageLinks),
      from: from,
      to: to,
      storeOf: _storeOf,
    );
    if (_closed) return;
    switch (followed) {
      case Err():
        _hint(
          "Couldn't take the images along: the folder can't be "
          'written now.',
        );
      case Ok(value: final relink):
        _linksFrom = to;
        if (relink != null) _gate.external(RelinkImages(relink));
    }
  }
}
