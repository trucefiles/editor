import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test('asks to list the folder again at every interval', () async {
    final queue = StreamQueue(
      const PolledFolderChanges(interval: Duration(milliseconds: 10)).changes,
    );
    addTearDown(queue.cancel);

    expect(await queue.take(3), List.filled(3, const ListAgain()));
  });
}
