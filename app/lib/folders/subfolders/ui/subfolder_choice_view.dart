import 'package:flutter/material.dart';

import '../subfolder_choice.dart';
import 'subfolder_tree.dart';

/// The choice between the whole base folder and some subfolders, with the
/// tree to pick them; then what the app shows there.
class SubfolderChoiceView extends StatelessWidget {
  const SubfolderChoiceView(this.choice, {super.key});

  final SubfolderChoice choice;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: choice,
    builder: (context, _) => RadioGroup<bool>(
      groupValue: choice.whole,
      onChanged: (whole) => choice.chooseWhole(whole: whole ?? false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioListTile<bool>(
            value: true,
            enabled: !choice.wholeTaken,
            title: const Text('Whole folder'),
            subtitle: choice.wholeTaken
                ? const Text('Another folder shows part of it.')
                : null,
          ),
          const RadioListTile<bool>(
            value: false,
            title: Text('Some subfolders'),
          ),
          if (!choice.whole)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16),
              child: SubfolderTree(choice),
            ),
          const SizedBox(height: 16),
          Text(
            'The app shows Markdown and text files in the chosen '
            'subfolders. More file types are planned.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
