import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/file_page/ui/file_place_spot.dart';

void main() {
  test('the place is in the menu only where the setting says and the page '
      'has a menu', () {
    expect(
      [
        for (final (aboveText, readOnly) in [
          (true, false),
          (false, false),
          (true, true),
          (false, true),
        ])
          filePlaceSpot(aboveText: aboveText, readOnly: readOnly),
      ],
      [
        FilePlaceSpot.aboveText,
        FilePlaceSpot.menu,
        FilePlaceSpot.aboveText,
        // A read-only page has no menu; a new file can still be placed.
        FilePlaceSpot.aboveText,
      ],
    );
  });
}
