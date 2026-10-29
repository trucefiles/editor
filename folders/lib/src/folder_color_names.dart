/// The first of [offered], a folder palette's color names, that [used]
/// doesn't hold, so new folders differ by default; once all are used,
/// they repeat in order.
String nextFolderColor(Iterable<String> used, List<String> offered) {
  final taken = used.toSet();
  return offered.firstWhere(
    (name) => !taken.contains(name),
    orElse: () => offered[taken.length % offered.length],
  );
}
