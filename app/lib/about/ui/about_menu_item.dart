import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/open_link.dart';
import '../app_version.dart';

/// Where the app's source code is.
final sourceLink = Uri.parse('https://github.com/trucefiles/editor');

/// Menu entry that shows the app's version, license and links.
PopupMenuItem<VoidCallback> aboutMenuItem(
  BuildContext context,
  WidgetRef ref,
) =>
    PopupMenuItem(value: () => _show(context, ref), child: const Text('About'));

Future<void> _show(BuildContext context, WidgetRef ref) async {
  final version = await ref.read(appVersionProvider.future);
  if (!context.mounted) return;
  showAboutDialog(
    context: context,
    applicationName: 'Truce Editor',
    applicationVersion: 'Version $version',
    applicationIcon: Image.asset(
      'linux/flatpak/io.github.trucefiles.editor-128.png',
      width: 48,
      height: 48,
    ),
    applicationLegalese: 'Free software under the GPL-3.0 license.',
    children: [
      const SizedBox(height: 16),
      const Text(
        'Your documents, shared between your devices and people, '
        'with no server in the middle.',
      ),
      const SizedBox(height: 8),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Source code'),
          onPressed: () => openLink(context, ref, sourceLink),
        ),
      ),
    ],
  );
}
