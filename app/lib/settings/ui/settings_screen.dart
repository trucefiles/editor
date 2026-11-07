import 'package:flutter/material.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

import '../../file_page/ui/place_above_text_tile.dart';
import '../../files/home/ui/recently_edited_tiles.dart';
import '../../files/new_file_place/ui/new_file_place_tile.dart';
import '../../refresh/ui/refresh_setting_tile.dart';
import '../../text_zoom/text_zoom_target.dart';
import '../../text_zoom/ui/text_zoom_tile.dart';
import '../../tray/ui/close_to_tray_tile.dart';
import 'add_item_place_tile.dart';

/// The app-wide settings of this device.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: PageWidth(
      builder: (_, padding) => ListView(
        padding: padding,
        children: const [
          NewFilePlaceTile(),
          RecentCountTile(),
          RecentAgeTile(),
          AddItemPlaceTile(),
          PlaceAboveTextTile(),
          TextZoomTile(TextZoomTarget.documents),
          TextZoomTile(TextZoomTarget.app),
          RefreshSettingTile(),
          CloseToTrayTile(),
        ],
      ),
    ),
  );
}

/// Opens the [SettingsScreen].
Future<void> openSettings(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
);
