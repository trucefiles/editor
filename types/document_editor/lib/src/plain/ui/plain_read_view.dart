import 'package:flutter/material.dart';

import '../../document_text_styles.dart';

/// A plain [text] to read, as written, in the document's body text;
/// selectable.
class PlainReadView extends StatelessWidget {
  const PlainReadView(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
    child: SelectableText(
      text,
      style: DocumentTextStyles.body(Theme.of(context)),
    ),
  );
}
