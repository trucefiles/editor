import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/android/isolate_planner_role.dart';

void main() {
  test('one plans at a time: the other asks it to plan again, and plans '
      'once it is free', () async {
    final (app, check) = (IsolatePlannerRole(), IsolatePlannerRole());
    addTearDown(app.release);
    addTearDown(check.release);
    var asked = 0;
    await app.take(onAsked: () => asked++);

    expect(await check.takeOrAsk(), isFalse);
    expect(asked, 1);

    app.release();
    expect(await check.takeOrAsk(), isTrue);
  });

  test('a waiting app takes the role once the check gives it up', () async {
    final (app, check) = (IsolatePlannerRole(), IsolatePlannerRole());
    addTearDown(app.release);
    addTearDown(check.release);
    expect(await check.takeOrAsk(), isTrue);

    var taken = false;
    final waiting = app.take(onAsked: () {}).then((_) => taken = true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(taken, isFalse);

    check.release();
    await waiting;
    expect(taken, isTrue);
  });
}
