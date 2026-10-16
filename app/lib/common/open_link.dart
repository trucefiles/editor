import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/link_opener.dart';
import 'snack.dart';

/// Opens [link] in the app the system picks for it; a hint says so if none
/// could.
Future<void> openLink(BuildContext context, WidgetRef ref, Uri link) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await ref.read(linkOpenerProvider).open(link)) {
    messenger.showHint('No app could open $link');
  }
}
