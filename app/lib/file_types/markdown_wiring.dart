import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_document_editor/truce_document_editor.dart';

import '../platform/link_opener.dart';
import '../settings/device_settings.dart';
import '../settings/device_settings_controller.dart';

/// What Markdown views get from the app: the Add item setting and the
/// system's link opener.
final markdownServicesProvider = Provider<MarkdownServices>(
  (ref) => MarkdownServices(
    addItems: ref.watch(_addItemPlaceProvider),
    openLink: ref.watch(linkOpenerProvider).open,
  ),
);

/// Where lists get Add item buttons, as the setting changes.
final _addItemPlaceProvider = Provider<ValueListenable<AddItemPlace>>((ref) {
  final place = ValueNotifier(DeviceSettings.standard.addItemPlace);
  ref
    ..listen(
      deviceSettingsProvider.select((s) => s.value?.addItemPlace),
      (_, now) => place.value = now ?? place.value,
      fireImmediately: true,
    )
    ..onDispose(place.dispose);
  return place;
});
