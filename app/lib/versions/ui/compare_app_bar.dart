import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../folders/document_folder.dart';
import '../../folders/ui/folder_badge.dart';

/// The app bar of a screen comparing two versions of the document at [file] in
/// [folder]; [reason], if given, tells below why there are two.
AppBar compareAppBar({
  required DocumentFolder folder,
  required RelPath file,
  String? reason,
}) => AppBar(
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(file.name, overflow: TextOverflow.ellipsis),
      FolderBadge(folder, file: file),
    ],
  ),
  bottom: reason == null
      ? null
      : PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Text(reason),
        ),
);
