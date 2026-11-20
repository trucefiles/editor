import 'dart:typed_data';

import '../text/text_file.dart';

/// [bytes] of a version as text to show and compare (see
/// [TextFile.textToShow]). Writing always uses the original bytes.
String versionText(Uint8List bytes) => TextFile.textToShow(bytes);
