import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/app_storage.dart';
import 'quick_note_draft.dart';

final quickNoteDraftsProvider = Provider<QuickNoteDrafts>(
  (ref) =>
      QuickNoteDrafts(File(ref.watch(appStorageProvider).quickNoteDraftPath)),
);
