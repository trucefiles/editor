import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

import 'editor/editor_robot.dart';

const _out = '/mnt/project-files/screenshots/app-step';
const _doc = '''# Weekend

Pick up the **bike** from the shop, then call *Anna*.
A second line of the same paragraph.

- [ ] milk
- [ ] bread
  - [ ] whole grain
  - [ ] rolls
- [x] eggs

1. first
2. second

> A quote with `code` and a [link](https://example.org).

| a | b |
|---|---|
| 1 | 2 |
''';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    const m = '/opt/flutter/bin/cache/artifacts/material_fonts';
    await _font('Roboto', [
      '$m/Roboto-Regular.ttf',
      '$m/Roboto-Bold.ttf',
      '$m/Roboto-Italic.ttf',
      '$m/Roboto-Medium.ttf',
    ]);
    await _font('MaterialIcons', ['$m/MaterialIcons-Regular.otf']);
    await _font('monospace', [
      '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
    ]);
  });

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final box = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = await tester.runAsync(() async {
      final img = await box.toImage(pixelRatio: 1.5);
      return img.toByteData(format: ui.ImageByteFormat.png);
    });
    File('$_out/$name.png').writeAsBytesSync(image!.buffer.asUint8List());
  }

  for (final (name, touch, scale, mode, dark) in [
    ('visual_desktop', false, 1.0, EditMode.visual, false),
    ('visual_touch', true, 1.0, EditMode.visual, false),
    ('visual_touch_large_text', true, 1.4, EditMode.visual, false),
    ('visual_desktop_dark', false, 1.0, EditMode.visual, true),
    ('markdown_desktop', false, 1.0, EditMode.markdown, false),
    ('read_desktop', false, 1.0, EditMode.read, false),
  ]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(540, 1100) * 1.5;
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      final base = dark ? ThemeData.dark() : ThemeData.light();
      await pumpDocument(
        tester,
        TestDocument(_doc, mode: mode),
        theme: base.copyWith(
          materialTapTargetSize: touch
              ? MaterialTapTargetSize.padded
              : MaterialTapTargetSize.shrinkWrap,
        ),
        around: (context, child) => RepaintBoundary(
          key: const ValueKey('shot'),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      );
      if (mode == EditMode.visual) {
        await tester.caretIn(checkboxNodeOf(index: 1), 3);
      }
      await shoot(tester, name);
    });
  }

  testWidgets('visual_dragging', (tester) async {
    tester.view.physicalSize = const Size(540, 1100) * 1.5;
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await pumpDocument(
      tester,
      TestDocument(_doc),
      around: (context, child) =>
          RepaintBoundary(key: const ValueKey('shot'), child: child!),
    );
    final handle = tester.getCenter(find.byIcon(Icons.drag_indicator).at(1));
    final gesture = await tester.startGesture(handle);
    await tester.pump();
    await gesture.moveBy(const Offset(0, 50));
    await tester.pump(const Duration(milliseconds: 300));
    await shoot(tester, 'visual_dragging');
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
