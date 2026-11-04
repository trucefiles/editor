import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore source;
  late MemoryFileStore target;
  late FileVersion version;

  setUp(() {
    source = MemoryFileStore();
    target = MemoryFileStore();
    version = source.put('a.md', 'text').version;
  });

  Future<Result<FileEntry, MoveError>> move({
    FileStore? into,
    String to = 'sub/b.md',
  }) => moveByCopy(
    source,
    path('a.md'),
    ifUnchanged: version,
    target: into ?? target,
    to: path(to),
  );

  test('moves the bytes into another folder', () async {
    final moved = await move();

    expect(moved.value.path, path('sub/b.md'));
    expect(target.textOf('sub/b.md'), 'text');
    expect(source.textOf('a.md'), isNull);
  });

  test('moves inside one folder alike', () async {
    final moved = await move(into: source);

    expect(moved.value.path, path('sub/b.md'));
    expect(source.textOf('sub/b.md'), 'text');
    expect(source.textOf('a.md'), isNull);
  });

  test('never overwrites a file at the target', () async {
    target.put('sub/b.md', 'other');

    final moved = await move();

    expect((moved.error as NotMoved).error, StoreError.alreadyExists);
    expect(target.textOf('sub/b.md'), 'other');
    expect(source.textOf('a.md'), 'text');
  });

  test('a file changed since leaves nothing moved and no copy', () async {
    source.put('a.md', 'changed');

    final moved = await move();

    expect((moved.error as NotMoved).error, StoreError.changedSinceRead);
    expect(source.textOf('a.md'), 'changed');
    expect(target.textOf('sub/b.md'), isNull);
  });

  test('a changed file whose copy can not be removed again says both '
      'stay', () async {
    source.put('a.md', 'changed');

    final moved = await moveByCopy(
      source,
      path('a.md'),
      ifUnchanged: version,
      target: _FailingDelete(target),
      to: path('b.md'),
    );

    final error = moved.error as CopiedOnly;
    expect(error.error, StoreError.changedSinceRead);
    expect(error.copy.path, path('b.md'));
    expect(source.textOf('a.md'), 'changed');
    expect(target.textOf('b.md'), 'changed');
  });

  test('an original that can not be removed stays beside its copy', () async {
    final failing = _FailingDelete(source);

    final moved = await moveByCopy(
      failing,
      path('a.md'),
      ifUnchanged: version,
      target: target,
      to: path('b.md'),
    );

    final error = moved.error as CopiedOnly;
    expect(error.error, StoreError.accessDenied);
    expect(error.copy.path, path('b.md'));
    expect(source.textOf('a.md'), 'text');
    expect(target.textOf('b.md'), 'text');
  });
}

/// [inner] that deletes nothing: access denied.
final class _FailingDelete extends ForwardingStore {
  _FailingDelete(super.inner);

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) async => const Err(StoreError.accessDenied);
}
