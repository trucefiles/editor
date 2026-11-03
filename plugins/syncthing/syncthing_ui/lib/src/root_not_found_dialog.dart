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
        title: const Text(
          'Pick the Syncthing folder itself for version '
          'history',
        ),
        content: const Text(
          "Couldn't find the Syncthing folder this folder belongs "
          "to. Without it, the app can't use Syncthing's version "
          'history and ignore rules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, RootChoice.continueHere),
            child: const Text('Continue with this folder'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, RootChoice.pickRoot),
            child: const Text('Pick it'),
          ),
        ],
      ),
    );
