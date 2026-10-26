import '../../tree/blocks.dart';
import '../draft.dart';
import 'frames.dart';

/// The bullet character or number delimiter of [draft]'s markers (its
/// [items]): its first old item's of its kind, else the document's
/// [bullet] or `.`.
String markerFamily(
  ListDraft draft,
  List<ItemDraft> items, {
  required String bullet,
}) {
  final marker = [
    ...items.map((item) => item.from?.marker),
    ...?draft.from?.items.map((item) => item.marker),
  ].nonNulls.where((marker) => marker.kind == draft.kind).firstOrNull;
  return switch (draft.kind) {
    ListKind.bullet => marker?.bullet ?? bullet,
    ListKind.numbered => marker?.delimiter ?? '.',
  };
}

/// The marker family that starts another list next to one of [family].
String otherFamily(String family) => switch (family) {
  '-' => '*',
  '*' || '+' => '-',
  '.' => ')',
  _ => '.',
};

/// The marker style of a new first item in [list]: its old first
/// item's.
MarkerStyle? neighborStyle(ListDraft list) =>
    switch (list.from?.items.firstOrNull) {
      final item? => MarkerStyle.of(item),
      null => null,
    };
