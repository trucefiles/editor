import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/snack.dart';
import '../../file_page/ui/file_screen.dart';
import '../file_actions.dart';
import 'open_failure_text.dart';

/// Opens [file] in the editor, with its text as it is now; tells the
/// user if it can't be read.
Future<void> openFile(
  BuildContext context,
  WidgetRef ref,
  ListedFile file,
) async {
  final read = await ref.read(fileActionsProvider).open(file);
  if (!context.mounted) return;
  switch (read) {
    case Ok(value: final opened):
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => FileScreen(opened)),
      );
    case Err(:final error):
      showSnack(context, "This file can't be opened. ${error.text}");
  }
}
