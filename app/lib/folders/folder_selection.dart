import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../common/choice.dart';

/// Id of the folder the files grid is filtered to; `null` shows all.
final selectedFolderIdProvider = NotifierProvider<Choice<FolderId>, FolderId?>(
  Choice<FolderId>.new,
);
