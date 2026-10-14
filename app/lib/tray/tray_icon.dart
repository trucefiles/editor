import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// A tray icon image as tray hosts take it: ARGB pixels, byte by byte.
final class TrayIcon {
  const TrayIcon({
    required this.width,
    required this.height,
    required this.argb,
  });

  /// From straight RGBA pixels, as `dart:ui` decodes them.
  factory TrayIcon.fromRgba(int width, int height, Uint8List rgba) {
    final argb = Uint8List(rgba.length);
    for (var i = 0; i < rgba.length; i += 4) {
      argb[i] = rgba[i + 3];
      argb[i + 1] = rgba[i];
      argb[i + 2] = rgba[i + 1];
      argb[i + 3] = rgba[i + 2];
    }
    return TrayIcon(width: width, height: height, argb: argb);
  }

  /// Decodes the image asset at [key].
  static Future<TrayIcon> load(String key) async {
    final data = await rootBundle.load(key);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final rgba = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final icon = TrayIcon.fromRgba(
      image.width,
      image.height,
      rgba!.buffer.asUint8List(),
    );
    image.dispose();
    codec.dispose();
    return icon;
  }

  final int width;
  final int height;
  final Uint8List argb;
}
