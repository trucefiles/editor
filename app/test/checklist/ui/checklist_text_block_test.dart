import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/checklist/ui/checklist_text_block.dart';
import 'package:truce_editor/platform/link_opener.dart';

void main() {
  testWidgets('opens a web link on tap', (tester) async {
    final links = _FakeLinkOpener();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [linkOpenerProvider.overrideWithValue(links)],
        child: const MaterialApp(
          home: Scaffold(
            body: ChecklistTextBlock('See [the site](https://example.org).'),
          ),
        ),
      ),
    );

    await tester.tapOnText(find.textRange.ofSubstring('the site'));
    await tester.pumpAndSettle();

    expect(links.opened, [Uri.parse('https://example.org')]);
  });
}

final class _FakeLinkOpener implements LinkOpener {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri link) async {
    opened.add(link);
    return true;
  }
}
