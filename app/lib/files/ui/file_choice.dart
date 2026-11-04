import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/snack.dart';
import '../../common/store_error_text.dart';
import '../file_actions.dart';
import '../file_settings_controller.dart';
import 'open_file.dart';

/// What the user picked from a file's actions.
sealed class FileChoice {
  const FileChoice();
}

/// Open the file's page.
final class OpenChoice extends FileChoice {
  const OpenChoice();
}

/// Pin the file on this device, or unpin it.
final class PinChoice extends FileChoice {
  const PinChoice({required this.pinned});

  final bool pinned;
}

/// Give the file a color on every device, or none (`null`).
final class ColorChoice extends FileChoice {
  const ColorChoice(this.color);

  final String? color;
}

/// Does what [choice] says for [file]; tells the user if a color can't
/// be saved.
Future<void> applyFileChoice(
  BuildContext context,
  WidgetRef ref,
  ListedFile file,
  FileChoice choice,
) async {
  switch (choice) {
    case OpenChoice():
      await openFile(context, ref, file);
    case PinChoice(:final pinned):
      await ref
          .read(fileSettingsProvider.notifier)
          .edit(file.key, (current) => current.withPinned(pinned: pinned));
    case ColorChoice(:final color):
      final actions = ref.read(fileActionsProvider);
      final saved = await actions.setMark(
        file,
        actions.markOf(file).withColor(color),
      );
      if (saved case Err(:final error) when context.mounted) {
        showSnack(context, error.text);
      }
  }
}
