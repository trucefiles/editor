import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/time_texts.dart';

/// The editor's title: the file's [title] (or the type's own title in
/// its place, [own]) and its last edit, if it has a file yet.
class FileHeading extends ConsumerWidget {
  const FileHeading({
    required this.title,
    required this.edited,
    this.own,
    super.key,
  });

  final String title;
  final DateTime? edited;
  final Widget? own;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edited = this.edited;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        own ?? Text(title, overflow: TextOverflow.ellipsis),
        if (edited != null)
          Text(
            'Edited ${ref.watch(timeTextsProvider).edited(edited, now: DateTime.now())}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }
}
