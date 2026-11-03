import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../common/picks.dart';

/// The file types the files grid is filtered to; none shows all.
final pickedFileTypesProvider =
    NotifierProvider<Picks<FileType>, Set<FileType>>(Picks<FileType>.new);
