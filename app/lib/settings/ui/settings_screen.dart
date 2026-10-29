import 'package:flutter/material.dart';

import '../../documents/home/ui/recent_count_tile.dart';
import '../../documents/new_file_place/ui/new_file_place_tile.dart';
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
    body: ListView(
      children: const [
        NewFilePlaceTile(),
        RecentCountTile(),
        AddItemPlaceTile(),
        TextZoomTile(TextZoomTarget.documents),
        TextZoomTile(TextZoomTarget.app),
        RefreshSettingTile(),
        CloseToTrayTile(),
      ],
    ),
  );
}

/// Opens the [SettingsScreen].
Future<void> openSettings(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
);
