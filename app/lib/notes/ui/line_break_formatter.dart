import 'package:flutter/services.dart';

/// Turns pasted `\r\n` and `\r` line breaks into `\n`: the editor's text
/// has `\n` breaks only, and saving puts the file's own breaks back.
final lineBreakFormatter = FilteringTextInputFormatter.deny(
  RegExp('\r\n?'),
  replacementString: '\n',
);
