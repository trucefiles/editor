import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../common/choice.dart';

/// The file type the files grid is filtered to; `null` shows all.
final selectedFileTypeProvider = NotifierProvider<Choice<FileType>, FileType?>(
  Choice<FileType>.new,
);
