import 'package:flutter/material.dart';

/// What to do when no Syncthing folder holds the picked directory.
enum RootChoice {
  /// Pick the Syncthing folder itself.
  pickRoot,

  /// Take the picked directory as the Syncthing folder.
  continueHere,
}

/// Asks what to do when no Syncthing folder was found at or above the
/// picked directory; `null` if dismissed.
Future<RootChoice?> showRootNotFound(BuildContext context) =>
    showDialog<RootChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick the whole Syncthing folder?'),
        content: const Text(
          "This folder is inside a Syncthing folder the app can't find. "
          'Pick that Syncthing folder so the app can use its version '
          'history and ignore rules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, RootChoice.continueHere),
            child: const Text('Continue with this folder'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, RootChoice.pickRoot),
            child: const Text('Pick Syncthing folder'),
          ),
        ],
      ),
    );
