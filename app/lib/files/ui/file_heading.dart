import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/time_texts.dart';

/// The editor's title: the file's [title], as [typeTitle] shows it (the
/// type may put its own in its place), and its last edit, if it has a
/// file yet.
class FileHeading extends ConsumerWidget {
  const FileHeading({
    required this.title,
    required this.edited,
    this.typeTitle,
    super.key,
  });

  final String title;
  final DateTime? edited;
  final Widget Function(Widget fileTitle)? typeTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edited = this.edited;
    final fileTitle = Text(title, overflow: TextOverflow.ellipsis);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        typeTitle?.call(fileTitle) ?? fileTitle,
        if (edited != null)
          Text(
            'Edited ${ref.watch(timeTextsProvider).edited(edited, now: DateTime.now())}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }
}
