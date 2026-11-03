import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../common/picks.dart';

/// Ids of the folders the files grid is filtered to; none shows all.
final pickedFoldersProvider = NotifierProvider<Picks<FolderId>, Set<FolderId>>(
  Picks<FolderId>.new,
);
