/// [bytes] as people read a file's size, e.g. `820 bytes`, `1.4 KB`,
/// `12 MB`: in steps of 1024, with one decimal below 10.
String sizeText(int bytes) {
  if (bytes < 1024) return bytes == 1 ? '1 byte' : '$bytes bytes';
  final (value, unit) = _units.fold((
    bytes / 1024,
    'KB',
  ), (shown, unit) => shown.$1 >= 1024 ? (shown.$1 / 1024, unit) : shown);
  return '${value < 10 ? value.toStringAsFixed(1) : value.round()} $unit';
}

const _units = ['MB', 'GB', 'TB'];
