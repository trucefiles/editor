import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import '../../common/snack.dart';
import '../../file_page/ui/file_view_page.dart';
import '../../file_page/ui/text_edit_page.dart';
import '../../file_types/file_types.dart';
import '../file_actions.dart';
import 'open_failure_text.dart';

/// Opens [file] on the page its type opens on: a text file as it is
/// now, telling the user if it can't be read; a file only shown as
/// listed, read as it shows.
Future<void> openFile(
  BuildContext context,
  WidgetRef ref,
  ListedFile file,
) async {
  switch (ref.read(fileTypesProvider).ofFile(file.type)) {
    case final ViewType type:
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => FileViewPage(file, type: type)),
      );
    case final EditableType type:
      await _openText(context, ref, file, type);
  }
}

Future<void> _openText(
  BuildContext context,
  WidgetRef ref,
  ListedFile file,
  EditableType type,
) async {
  final read = TextFiles.textOf(await ref.read(fileActionsProvider).read(file));
  if (!context.mounted) return;
  switch (read) {
    case Ok(value: final opened):
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TextEditPage(opened, type: type),
        ),
      );
    case Err(:final error):
      showSnack(context, "This file can't be opened. ${error.text}");
  }
}
