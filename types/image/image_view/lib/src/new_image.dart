import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_images/truce_images.dart';

/// Asks the user for a picture by [picking]: from its one source, or the
/// one they pick of several; made ready as its settings say. A picked
/// file keeps its name (with its kind's extension), a new photo is named
/// by when it was taken ([now]). `null` if none was picked; [hint] tells
/// if it was no picture the app shows. [prepare] makes it ready, away
/// from the screen's thread.
Future<NewContent?> askForImage(
  BuildContext context,
  ImagePicking picking, {
  required void Function(String message) hint,
  DateTime Function() now = DateTime.now,
  Future<PreparedImage?> Function(Uint8List bytes, ImageSettings settings)
      prepare =
      prepareInBackground,
}) async {
  final source = switch (picking.sources) {
    [final only] => only,
    final sources => await _askSource(context, sources),
  };
  if (source == null) return null;
  final picked = await picking.pick(source);
  if (picked == null) return null;
  final prepared = await prepare(picked.bytes, picking.settings);
  if (prepared == null) {
    hint("That file isn't an image the app can show.");
    return null;
  }
  return (
    bytes: prepared.bytes,
    name:
        '${_baseOf(picked.name) ?? photoName(now())}.'
        '${prepared.kind.extension}',
  );
}

/// [name] without its extension; `null` for none or an empty one.
String? _baseOf(String? name) => switch (name) {
  final name? when name.trim().isNotEmpty => switch (name.lastIndexOf('.')) {
    > 0 && final dot => name.substring(0, dot),
    _ => name,
  },
  _ => null,
};

/// The name of a photo taken at [at], e.g. `Photo 2026-11-20 13-05-09`:
/// sorted by time, and fit for any file system.
String photoName(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'Photo ${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}-${two(at.minute)}-${two(at.second)}';
}

/// Which of [sources] the user picks from; `null` if they pick none.
Future<ImageSource?> _askSource(
  BuildContext context,
  List<ImageSource> sources,
) => showModalBottomSheet<ImageSource>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final source in sources)
          ListTile(
            leading: Icon(switch (source) {
              ImageSource.file => Icons.photo_library_outlined,
              ImageSource.camera => Icons.photo_camera_outlined,
            }),
            title: Text(switch (source) {
              ImageSource.file => 'Choose image',
              ImageSource.camera => 'Take photo',
            }),
            onTap: () => Navigator.pop(context, source),
          ),
      ],
    ),
  ),
);
