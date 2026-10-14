import 'package:dbus/dbus.dart';

import '../tray_icon.dart';

/// The tray icon as a D-Bus object, after the StatusNotifierItem spec that
/// KDE, GNOME's AppIndicator extension and most other trays follow.
final class StatusNotifierItem extends DBusObject {
  StatusNotifierItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.menu,
    required this.onActivate,
  }) : super(objectPath);

  static final objectPath = DBusObjectPath('/StatusNotifierItem');
  static const interfaceName = 'org.kde.StatusNotifierItem';

  /// Stable name of the app, e.g. its app id.
  final String id;
  final String title;
  final TrayIcon icon;

  /// Path of the item's menu object.
  final DBusObjectPath menu;

  /// Runs on a primary click on the icon.
  final void Function() onActivate;

  late final Map<String, DBusValue> _properties = {
    'Category': const DBusString('ApplicationStatus'),
    'Id': DBusString(id),
    'Title': DBusString(title),
    'Status': const DBusString('Active'),
    'IconName': const DBusString(''),
    'IconPixmap': _pixmaps([
      DBusStruct([
        DBusInt32(icon.width),
        DBusInt32(icon.height),
        DBusArray.byte(icon.argb),
      ]),
    ]),
    'ToolTip': DBusStruct([
      const DBusString(''),
      _pixmaps(const []),
      DBusString(title),
      const DBusString(''),
    ]),
    'ItemIsMenu': const DBusBoolean(false),
    'Menu': menu,
  };

  static DBusArray _pixmaps(List<DBusValue> pixmaps) =>
      DBusArray(DBusSignature('(iiay)'), pixmaps);

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != interfaceName) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (methodCall.name) {
      case 'Activate':
        onActivate();
        return DBusMethodSuccessResponse();
      // The tray shows the menu itself; nothing else to do.
      case 'ContextMenu' ||
          'SecondaryActivate' ||
          'Scroll' ||
          'ProvideXdgActivationToken':
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = interface == interfaceName ? _properties[name] : null;
    return value == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(
        interface == interfaceName ? _properties : const {},
      );
}
