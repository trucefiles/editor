/// How many characters [a] and [b] share at their start ([head]) and,
/// after that, at their end ([tail]).
({int head, int tail}) commonEnds(String a, String b) {
  int same(String a, String b) =>
      Iterable<int>.generate(a.length < b.length ? a.length : b.length)
          .takeWhile((index) => a[index] == b[index])
          .length;
  String reversed(String text) => text.split('').reversed.join();
  final head = same(a, b);
  return (
    head: head,
    tail: same(reversed(a.substring(head)), reversed(b.substring(head))),
  );
}
