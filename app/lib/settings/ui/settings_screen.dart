import 'package:flutter/material.dart';

import '../../notes/new_note_place/ui/new_note_place_tile.dart';
import '../../refresh/ui/refresh_setting_tile.dart';
import '../../tray/ui/close_to_tray_tile.dart';

/// The app-wide settings of this device.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: const [
        NewNotePlaceTile(),
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
