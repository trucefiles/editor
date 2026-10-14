import 'package:dbus/dbus.dart';

/// One entry of the tray menu.
final class TrayMenuEntry {
  const TrayMenuEntry(this.label, this.onClicked);

  final String label;
  final void Function() onClicked;
}

/// The tray icon's menu as a D-Bus object, after the DBusMenu protocol
/// trays use to show an item's menu. A flat, fixed list of [entries].
final class DBusMenu extends DBusObject {
  DBusMenu(this.entries) : super(objectPath);

  static final objectPath = DBusObjectPath('/MenuBar');
  static const interfaceName = 'com.canonical.dbusmenu';

  /// The entries, with ids from 1 on; 0 is the root holding them.
  final List<TrayMenuEntry> entries;

  /// The layout never changes, so it keeps its first revision.
  static const _revision = DBusUint32(1);

  /// Signature of the arguments of each method.
  static const _signatures = {
    'GetLayout': 'iias',
    'GetGroupProperties': 'aias',
    'GetProperty': 'is',
    'Event': 'isvu',
    'EventGroup': 'a(isvu)',
    'AboutToShow': 'i',
    'AboutToShowGroup': 'ai',
  };

  static const _properties = {
    'Version': DBusUint32(3),
    'TextDirection': DBusString('ltr'),
    'Status': DBusString('normal'),
  };

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != interfaceName) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final expected = _signatures[methodCall.name];
    if (expected == null) return DBusMethodErrorResponse.unknownMethod();
    if (methodCall.signature.value != expected) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    final args = methodCall.values;
    return switch (methodCall.name) {
      'GetLayout' => _layout(args[0].asInt32(), args[1].asInt32()),
      'GetGroupProperties' => _groupProperties(args[0].asInt32Array().toList()),
      'GetProperty' => _property(args[0].asInt32(), args[1].asString()),
      'Event' => _event(args[0].asInt32(), args[1].asString()),
      'EventGroup' => _eventGroup(args[0].asArray()),
      // The menu never changes, so it never needs an update.
      'AboutToShow' => DBusMethodSuccessResponse([const DBusBoolean(false)]),
      _ => DBusMethodSuccessResponse([
        DBusArray.int32(const []),
        DBusArray.int32(const []),
      ]),
    };
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

  bool _known(int id) => id >= 0 && id <= entries.length;

  Map<String, DBusValue> _propertiesOf(int id) => id == 0
      ? const {'children-display': DBusString('submenu')}
      : {'label': DBusString(entries[id - 1].label)};

  /// One item and, while [depth] allows, the items below it; -1 is all.
  DBusStruct _node(int id, int depth) => DBusStruct([
    DBusInt32(id),
    DBusDict.stringVariant(_propertiesOf(id)),
    DBusArray.variant([
      if (id == 0 && depth != 0)
        for (var child = 1; child <= entries.length; child++)
          _node(child, depth - 1),
    ]),
  ]);

  DBusMethodResponse _layout(int parent, int depth) => _known(parent)
      ? DBusMethodSuccessResponse([_revision, _node(parent, depth)])
      : DBusMethodErrorResponse.invalidArgs('Unknown menu item $parent');

  /// Properties of [ids], or of every item if none are given.
  DBusMethodResponse _groupProperties(List<int> ids) {
    final wanted = ids.isEmpty
        ? [for (var id = 0; id <= entries.length; id++) id]
        : ids.where(_known);
    return DBusMethodSuccessResponse([
      DBusArray(DBusSignature('(ia{sv})'), [
        for (final id in wanted)
          DBusStruct([
            DBusInt32(id),
            DBusDict.stringVariant(_propertiesOf(id)),
          ]),
      ]),
    ]);
  }

  DBusMethodResponse _property(int id, String name) {
    final value = _known(id) ? _propertiesOf(id)[name] : null;
    return value == null
        ? DBusMethodErrorResponse.invalidArgs('Unknown property $name of $id')
        : DBusMethodSuccessResponse([DBusVariant(value)]);
  }

  DBusMethodResponse _event(int id, String event) {
    if (!_known(id)) {
      return DBusMethodErrorResponse.invalidArgs('Unknown menu item $id');
    }
    if (event == 'clicked' && id > 0) entries[id - 1].onClicked();
    return DBusMethodSuccessResponse();
  }

  /// Runs each event; answers the ids that are unknown.
  DBusMethodResponse _eventGroup(List<DBusValue> events) {
    final unknown = <int>[];
    for (final event in events) {
      final [id, name, _, _] = event.asStruct();
      if (_known(id.asInt32())) {
        _event(id.asInt32(), name.asString());
      } else {
        unknown.add(id.asInt32());
      }
    }
    return DBusMethodSuccessResponse([DBusArray.int32(unknown)]);
  }
}
