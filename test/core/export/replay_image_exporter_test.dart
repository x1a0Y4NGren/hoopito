import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/export/replay_image_exporter.dart';

void main() {
  testWidgets('captures a RepaintBoundary as a usable PNG', (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: const SizedBox(
              width: 120,
              height: 80,
              child: ColoredBox(color: Colors.deepOrange),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final bytes = await tester.runAsync(
      () => ReplayImageExporter.capture(boundaryKey, pixelRatio: 2),
    );
    final codec = await tester.runAsync(() => ui.instantiateImageCodec(bytes!));
    final frame = await tester.runAsync(codec!.getNextFrame);
    addTearDown(codec.dispose);
    addTearDown(frame!.image.dispose);

    expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(frame.image.width, 240);
    expect(frame.image.height, 160);
  });
}
