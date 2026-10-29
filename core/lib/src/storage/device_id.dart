import 'dart:io';
import 'dart:math';

/// This app install's random id, made on first start and kept in [file].
/// Names the files this device writes into synced folders.
///
/// If the id cannot be saved, the next start makes a new one; files under
/// the old id still count, they just get no more writes.
Future<String> loadDeviceId(File file) async {
  try {
    final saved = (await file.readAsString()).trim();
    if (_isValid(saved)) return saved;
  } on FileSystemException {
    // Not made yet, or unreadable: make a new one.
  }
  final id = _newId();
  try {
    await file.parent.create(recursive: true);
    await file.writeAsString(id, flush: true);
  } on FileSystemException {
    // Works for this run; see above.
  }
  return id;
}

final _idPattern = RegExp(r'^[0-9a-f]{16}$');

bool _isValid(String id) => _idPattern.hasMatch(id);

String _newId() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 8; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
