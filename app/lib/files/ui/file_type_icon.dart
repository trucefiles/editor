import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../../file_types/file_types.dart';

/// The icon of [file]'s type, as the type states it, named by the type
/// on hover; as large as the icons around it.
class FileTypeIcon extends ConsumerWidget {
  const FileTypeIcon(this.file, {super.key});

  final ListedFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(fileTypesProvider).ofFile(file.type);
    return Tooltip(message: type.name, child: Icon(type.icon));
  }
}
