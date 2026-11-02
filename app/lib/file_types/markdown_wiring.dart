import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_document_editor/truce_document_editor.dart';

import '../platform/link_opener.dart';
import '../settings/followed_setting.dart';

/// What Markdown views get from the app: the Add item setting and the
/// system's link opener.
final markdownServicesProvider = Provider<MarkdownServices>(
  (ref) => MarkdownServices(
    addItems: ref.watch(_addItemPlaceProvider),
    openLink: ref.watch(linkOpenerProvider).open,
  ),
);

/// Where lists get Add item buttons, as the setting changes.
final _addItemPlaceProvider = Provider<ValueListenable<AddItemPlace>>(
  (ref) => followedSetting(ref, (s) => s.addItemPlace),
);
