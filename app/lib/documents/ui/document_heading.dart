import 'package:flutter/material.dart';

import '../../common/time_texts.dart';

/// The editor's title: the document's title and its last edit, if it has a
/// file yet.
class DocumentHeading extends StatelessWidget {
  const DocumentHeading({required this.title, required this.edited, super.key});

  final String title;
  final DateTime? edited;

  @override
  Widget build(BuildContext context) {
    final edited = this.edited;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, overflow: TextOverflow.ellipsis),
        if (edited != null)
          Text(
            'Edited ${TimeTexts.of(context).edited(edited, now: DateTime.now())}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }
}
