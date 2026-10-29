import 'dart:convert';
import 'dart:typed_data';

import 'package:truce_core/truce_core.dart' show anyLineBreak;

/// [bytes] of a version as text to show and compare, with `\n` line
/// breaks, also for `\r\n` and old Mac `\r` files.
///
/// For display only; bytes that are not valid UTF-8 show as replacement
/// characters. Writing always uses the original bytes.
String versionText(Uint8List bytes) =>
    utf8.decode(bytes, allowMalformed: true).replaceAll(anyLineBreak, '\n');
