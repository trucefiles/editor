/// What an item shows before its text.
sealed class Marker {
  const Marker();
}

final class BoxMarker extends Marker {
  const BoxMarker({required this.checked});

  final bool checked;

  @override
  bool operator ==(Object other) =>
      other is BoxMarker && other.checked == checked;

  @override
  int get hashCode => Object.hash(BoxMarker, checked);
}

final class BulletMarker extends Marker {
  const BulletMarker();

  @override
  bool operator ==(Object other) => other is BulletMarker;

  @override
  int get hashCode => (BulletMarker).hashCode;
}

final class NumberMarker extends Marker {
  const NumberMarker(this.number);

  final int number;

  @override
  bool operator ==(Object other) =>
      other is NumberMarker && other.number == number;

  @override
  int get hashCode => Object.hash(NumberMarker, number);
}
