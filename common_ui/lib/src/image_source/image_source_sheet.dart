import 'package:flutter/material.dart';
import 'package:truce_images/truce_images.dart';

/// Which of [sources] a picture comes from: the only one at once, else
/// the one the user picks on a sheet from the bottom ("Choose image",
/// "Take photo"); `null` if they pick none.
Future<ImageSource?> askImageSource(
  BuildContext context,
  List<ImageSource> sources,
) async => switch (sources) {
  [final only] => only,
  _ => await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final source in sources)
            ListTile(
              leading: Icon(_icon(source)),
              title: Text(_label(source)),
              onTap: () => Navigator.pop(context, source),
            ),
        ],
      ),
    ),
  ),
};

String _label(ImageSource source) => switch (source) {
  ImageSource.file => 'Choose image',
  ImageSource.camera => 'Take photo',
};

IconData _icon(ImageSource source) => switch (source) {
  ImageSource.file => Icons.photo_library_outlined,
  ImageSource.camera => Icons.photo_camera_outlined,
};
