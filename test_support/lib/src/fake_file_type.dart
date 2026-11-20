import 'package:truce_core/truce_core.dart';

/// A made-up file type for tests of generic code: its files end in
/// `.md`.
final class FakeFileType implements FileTypeSupport {
  const FakeFileType();

  static const id = FileType('fake');

  @override
  FileType get type => id;

  @override
  Set<String> get extensions => const {'md'};
}

/// Detects the fake file type ([FakeFileType]).
const fakeFileTypes = ExtensionFileTypeDetector({'md': FakeFileType.id});
