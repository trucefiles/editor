/// The library's node ids for what Visual edit shows: one per look key
/// (see `RowLook.key`), kept while the key shows, so the caret and the
/// input method stay on a node while its row changes. Our own, never the
/// library's, but for the one a split asks for.
final class NodeIds {
  final _ids = <Object?, String>{};
  final _keys = <String, Object?>{};
  int _next = 0;

  /// The id of the node showing [key].
  String of(Object? key) => _ids[key] ??= _fresh(key);

  /// The id of the node showing [key]; `null` if none does yet.
  String? find(Object? key) => _ids[key];

  /// What node [id] shows; `null` if no key has it.
  Object? keyOf(String id) => _keys[id];

  /// Ids after the library split node [id]: [top] shows in it, [bottom]
  /// in the node [newId] the library expects below it.
  void split(
    String id, {
    required Object? top,
    required Object? bottom,
    required String newId,
  }) {
    _assign(top, id);
    _assign(bottom, newId);
  }

  /// Forgets the ids of keys not among [keys].
  void keepOnly(Set<Object?> keys) {
    _ids.removeWhere((key, _) => !keys.contains(key));
    _keys.removeWhere((_, key) => !keys.contains(key));
  }

  void _assign(Object? key, String id) {
    _keys.remove(_ids.remove(key));
    _ids.remove(_keys.remove(id));
    _ids[key] = id;
    _keys[id] = key;
  }

  String _fresh(Object? key) {
    final id = 'row-${_next++}';
    _keys[id] = key;
    return id;
  }
}
