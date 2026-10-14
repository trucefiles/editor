import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import 'hosted_tray.dart';

/// Tray icons from tray_manager: the image asset [iconAsset], with an
/// "Open" and a "Quit" entry that a click on the icon opens.
ShowTrayIcon nativeTrayIcon({
  required String iconAsset,
  required String tooltip,
}) => ({required onOpen, required onQuit}) {
  final icon = TrayIcon.create();
  final menu = Menu.create();
  if (icon == null || menu == null) return null;
  menu
    ..addItem(_entry('Open', onOpen))
    ..addItem(_entry('Quit', onQuit));
  icon
    ..icon = ImageAsset.fromAsset(iconAsset)
    ..setTooltip(tooltip)
    ..setContextMenu(menu)
    // Without a trigger the Linux tray gets no menu, and clicks do nothing.
    ..setContextMenuTrigger(ContextMenuTrigger.clicked)
    ..setVisible(true);
  return icon.dispose;
};

MenuItem? _entry(String label, VoidCallback onClicked) =>
    MenuItem.createWithLabelAndType(label, MenuItemType.normal)
      ?..addListener((event) {
        if (event is MenuItemClickedEvent) onClicked();
      });
