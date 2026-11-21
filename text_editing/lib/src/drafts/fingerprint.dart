import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A short value that tells whether two files hold the same [bytes]
/// (SHA-256, as hex), without keeping them.
String fingerprintOf(Uint8List bytes) => sha256.convert(bytes).toString();
