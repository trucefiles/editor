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
          'The Syncthing folder holding this folder could not be found. '
          "Without it, Syncthing's version history and ignore rules "
          "aren't used.",
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
