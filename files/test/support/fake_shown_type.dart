import 'dart:convert';
import 'dart:typed_data';

import 'package:truce_core/truce_core.dart' show SearchText;
import 'package:truce_files/truce_files.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// A made-up shown type for tests of generic code, read from bytes:
/// files of `key:value` lines, ending in `.md`. Cards are titled by the
/// first line; search finds the values; two files merge key by key.
final class FakeShownType implements ShownFileType {
  const FakeShownType();

  @override
  FakeFileType get support => const FakeFileType();

  @override
  String get name => 'Key value';

  @override
  List<NewFileKind> get newKinds => const [
    NewFileKind('Note'),
    NewFileKind('List'),
  ];

  @override
  FileCardSummary cardSummary(FileBytes read) =>
      FileCardSummary(title: _linesOf(read.bytes).first, preview: (_) => '');

  /// The values, not the keys.
  @override
  SearchText searchText(FileBytes read) => (
    title: _linesOf(read.bytes).first,
    text: [for (final line in _linesOf(read.bytes)) line.split(':').last]
        .join('\n'),
  );

  @override
  FileMerge get merge => const FakeFileMerge();
}

/// Merges two files of `key:value` lines: the main file's lines, then
/// the other's new keys; on a key both have, the main file's value is
/// kept and the key named as lost. A line without `:` can't be merged.
final class FakeFileMerge implements FileMerge {
  const FakeFileMerge();

  @override
  MergedSides? merge(Uint8List current, Uint8List other) {
    final main = _linesOf(current);
    final theirs = _linesOf(other);
    if ([...main, ...theirs].any((line) => !line.contains(':'))) return null;
    final keys = {for (final line in main) _keyOf(line)};
    return (
      bytes: utf8.encode(
        [
          ...main,
          ...theirs.where((line) => !keys.contains(_keyOf(line))),
        ].map((line) => '$line\n').join(),
      ),
      lost: [
        for (final line in theirs)
          if (keys.contains(_keyOf(line)) && !main.contains(line)) _keyOf(line),
      ],
    );
  }
}

String _keyOf(String line) => line.split(':').first;

List<String> _linesOf(Uint8List bytes) => [
  for (final line in latin1.decode(bytes).split('\n'))
    if (line.isNotEmpty) line,
];
