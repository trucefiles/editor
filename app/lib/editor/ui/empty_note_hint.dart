import 'package:flutter/material.dart';

import '../note_document_controller.dart';

/// "Untitled" where the first line goes while [note] is empty: never
/// saved, an empty note gets its name from the first line typed. Lets
/// every tap through to the editor below.
class EmptyNoteHint extends StatelessWidget {
  const EmptyNoteHint(this.note, {required this.padding, super.key});

  final NoteDocumentController note;

  /// Where the first line's text starts.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: note,
    builder: (context, _) => note.lines.text.isEmpty
        ? IgnorePointer(
            child: Padding(
              padding: padding,
              child: Text(
                'Untitled',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.4, color: Theme.of(context).hintColor),
              ),
            ),
          )
        : const SizedBox.shrink(),
  );
}
