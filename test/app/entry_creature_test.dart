import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/entry/entry_creature.dart';
import 'package:hoopito/app/entry/entry_motion_pose.dart';

void main() {
  test('mesh has one complete texture with 48 by 48 cells', () {
    final mesh = EntryCreatureMesh(imageWidth: 1024, imageHeight: 1024);
    expect(mesh.textureCoordinates.length, 49 * 49 * 2);
    expect(mesh.indices.length, 48 * 48 * 6);
    expect(mesh.textureCoordinates.take(2), [0, 0]);
    expect(mesh.textureCoordinates.skip(mesh.textureCoordinates.length - 2), [
      1024,
      1024,
    ]);
    expect(mesh.indices.every((index) => index < 49 * 49), isTrue);
  });

  test('mesh never folds and remains inside the native canvas at every ms', () {
    final mesh = EntryCreatureMesh(imageWidth: 1024, imageHeight: 1024);
    final positions = Float32List(EntryCreatureMesh.vertexCount * 2);
    var minimumArea = double.infinity;
    var minimumCoordinate = double.infinity;
    var maximumCoordinate = double.negativeInfinity;
    for (var ms = 0; ms <= 1000; ms++) {
      mesh.samplePositions(EntryMotionPose.sample(ms / 1000), into: positions);
      for (final coordinate in positions) {
        minimumCoordinate = math.min(minimumCoordinate, coordinate);
        maximumCoordinate = math.max(maximumCoordinate, coordinate);
      }
      for (var i = 0; i < mesh.indices.length; i += 3) {
        final a = mesh.indices[i] * 2;
        final b = mesh.indices[i + 1] * 2;
        final c = mesh.indices[i + 2] * 2;
        final twiceArea =
            (positions[b] - positions[a]) *
                (positions[c + 1] - positions[a + 1]) -
            (positions[b + 1] - positions[a + 1]) *
                (positions[c] - positions[a]);
        minimumArea = math.min(minimumArea, twiceArea);
      }
    }
    expect(minimumArea, greaterThan(0));
    expect(minimumCoordinate, greaterThanOrEqualTo(0));
    expect(maximumCoordinate, lessThanOrEqualTo(288));
  });

  test('eye, pupil and mouth inherit body motion without local ripples', () {
    final mesh = EntryCreatureMesh(imageWidth: 1024, imageHeight: 1024);
    for (final ms in [200, 300, 420, 540, 650, 690, 730]) {
      final pose = EntryMotionPose.sample(ms / 1000);
      final positions = mesh.samplePositions(pose);
      for (final (column, row) in [(26, 22), (28, 18), (23, 30)]) {
        final index = (row * 49 + column) * 2;
        final expected = _bodyPosition(column, row, pose);
        expect(positions[index], closeTo(expected.dx, 0.00001));
        expect(positions[index + 1], closeTo(expected.dy, 0.00001));
      }
    }
  });

  test('settled and zero-strength meshes restore every original vertex', () {
    final mesh = EntryCreatureMesh(imageWidth: 1024, imageHeight: 1024);
    final original = mesh.samplePositions(EntryMotionPose.sample(0));
    for (final t in [0.76, 0.8, 1.0]) {
      expect(mesh.samplePositions(EntryMotionPose.sample(t)), original);
    }
    expect(
      mesh.samplePositions(EntryMotionPose.sample(0.33, motionStrength: 0)),
      original,
    );
  });

  test('final ripple moves right through a narrow upper-body region', () {
    final mesh = EntryCreatureMesh(imageWidth: 1024, imageHeight: 1024);
    final rest = mesh.samplePositions(EntryMotionPose.rest);
    var previousColumn = -1;
    for (final ms in [645, 670, 695, 720, 745]) {
      final positions = mesh.samplePositions(EntryMotionPose.sample(ms / 1000));
      var strongestColumn = 0;
      var largestWave = 0.0;
      var affectedColumns = 0;
      for (var column = 0; column <= 48; column++) {
        final index = (10 * 49 + column) * 2 + 1;
        final wave = rest[index] - positions[index];
        if (wave > 0) affectedColumns++;
        if (wave > largestWave) {
          largestWave = wave;
          strongestColumn = column;
        }
        final bottomIndex = (35 * 49 + column) * 2 + 1;
        expect(positions[bottomIndex], rest[bottomIndex]);
      }
      expect(largestWave, greaterThan(0));
      expect(largestWave, lessThanOrEqualTo(2));
      expect(affectedColumns, lessThanOrEqualTo(7));
      expect(strongestColumn, greaterThan(previousColumn));
      previousColumn = strongestColumn;
    }
  });

  testWidgets('renderer changes the shared texture and restores exact pixels', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(32, 32),
      22,
      Paint()..color = const Color(0xFFFF5B16),
    );
    canvas.drawCircle(
      const Offset(36, 27),
      8,
      Paint()..color = const Color(0xFFF6F4EF),
    );
    canvas.drawCircle(
      const Offset(39, 24),
      4,
      Paint()..color = const Color(0xFF101112),
    );
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(64, 64));
    picture.dispose();
    addTearDown(image!.dispose);

    Future<Uint8List> render(
      double progress, {
      double strength = 1,
      EntryVerticesBuilder? verticesBuilder,
      VoidCallback? onFallback,
    }) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: const Key('creature'),
              child: EntryCreature(
                image: image,
                progress: progress,
                motionStrength: strength,
                verticesBuilder: verticesBuilder,
                onFallback: onFallback,
              ),
            ),
          ),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('creature')),
      );
      return (await tester.runAsync(() async {
        final frame = await boundary.toImage();
        try {
          final bytes = await frame.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          return bytes!.buffer.asUint8List();
        } finally {
          frame.dispose();
        }
      }))!;
    }

    final start = await render(0);
    expect(tester.getSize(find.byType(EntryCreature)), const Size(288, 288));
    expect(await render(0.33), isNot(orderedEquals(start)));
    expect(await render(0.69), isNot(orderedEquals(start)));
    expect(await render(0.76), orderedEquals(start));
    expect(await render(1), orderedEquals(start));
    expect(await render(0.33, strength: 0), orderedEquals(start));
    var failedAllocations = 0;
    var fallbacks = 0;
    ui.Vertices failAllocation(
      Float32List positions,
      Float32List textureCoordinates,
      Uint16List indices,
    ) {
      failedAllocations++;
      throw StateError('simulated backend allocation failure');
    }

    expect(
      await render(
        0.33,
        verticesBuilder: failAllocation,
        onFallback: () => fallbacks++,
      ),
      orderedEquals(start),
    );
    expect(
      await render(
        0.48,
        verticesBuilder: failAllocation,
        onFallback: () => fallbacks++,
      ),
      orderedEquals(start),
    );
    expect(failedAllocations, 1);
    expect(fallbacks, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Offset _bodyPosition(int column, int row, EntryMotionPose pose) {
  final x = (column * 6 - 144) * 0.78 * pose.scaleX;
  final y = (row * 6 - 144) * 0.78 * pose.scaleY;
  final cosine = math.cos(pose.rotationRadians);
  final sine = math.sin(pose.rotationRadians);
  return Offset(
    144 + x * cosine - y * sine,
    144 + x * sine + y * cosine + pose.offsetY,
  );
}
