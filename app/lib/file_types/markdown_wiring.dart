import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_document_editor/truce_document_editor.dart';

import '../images/images_wiring.dart';
import '../platform/link_opener.dart';
import '../platform/platform_wiring.dart';
import '../settings/followed_setting.dart';

/// What Markdown views get from the app: the Add item setting, the
/// system's link opener, the folders' document images and the
/// platform's picture picking.
final markdownServicesProvider = Provider<MarkdownServices>(
  (ref) => MarkdownServices(
    addItems: ref.watch(_addItemPlaceProvider),
    openLink: ref.watch(linkOpenerProvider).open,
    picking: ref.watch(imagePickingProvider),
    imagesOf: ref.watch(documentImageStoresProvider),
  ),
);

/// Where lists get Add item buttons, as the setting changes.
final _addItemPlaceProvider = Provider<ValueListenable<AddItemPlace>>(
  (ref) => followedSetting(ref, (s) => s.addItemPlace),
);
