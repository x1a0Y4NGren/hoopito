import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/value_objects/court_geometry.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/widgets/court_painter.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';
import 'package:hoopito/features/scoring/widgets/score_side_panel.dart';

void main() {
  test(
    'spotlight darkens invalid area and free throws use the fixed line center',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const painter = CourtPainter(
        surfaceColor: Colors.white,
        activeRegion: CourtRegion.outsideArc,
        freeThrowMarkers: [
          FreeThrowCourtMarker(eventId: 'ft', side: TeamSide.blue),
        ],
        teamBlueColor: Color(0xFF1234EF),
      );
      painter.paint(canvas, const Size(300, 280));
      final rendered = await recorder.endRecording().toImage(300, 280);
      final bytes = (await rendered.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      Color pixel(int x, int y) {
        final offset = (y * 300 + x) * 4;
        return Color.fromARGB(
          255,
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
      }

      expect(pixel(150, 116), const Color(0xFF1234EF));
      // Both sample pixels lie away from court lines and markers.
      expect(pixel(100, 70).r, lessThan(pixel(100, 240).r));
      rendered.dispose();
    },
  );

  test('spotlight path follows the arc and corner lines drawn on court', () {
    final inside = CourtPainter.regionPath(
      CourtRegion.insideArc,
      const Rect.fromLTWH(0, 0, 300, 280),
    );
    final outside = CourtPainter.regionPath(
      CourtRegion.outsideArc,
      const Rect.fromLTWH(0, 0, 300, 280),
    );
    for (final entry in <(Offset, bool)>[
      (const Offset(150, 165), true),
      (const Offset(150, 168), false),
      (const Offset(12, 20), false),
      (const Offset(22, 20), true),
      (const Offset(278, 20), true),
      (const Offset(288, 20), false),
    ]) {
      expect(inside.contains(entry.$1), entry.$2, reason: '${entry.$1}');
      expect(outside.contains(entry.$1), !entry.$2, reason: '${entry.$1}');
    }
  });
  Future<void> mount(WidgetTester tester, Widget court) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 600, height: 280, child: court)),
      ),
    ),
  );
  Offset position(WidgetTester tester, double x, double y) {
    final rect = tester.getRect(find.byType(CourtView));
    return rect.topLeft +
        HalfCourtGeometry.pointToOffset(CourtPoint(x: x, y: y), rect.size);
  }

  testWidgets('invalid regions and letterboxing never submit locations', (
    tester,
  ) async {
    var accepted = 0;
    var invalid = 0;
    await mount(
      tester,
      CourtView(
        shotLocations: const [],
        activeRegion: CourtRegion.insideArc,
        reduceMotion: true,
        onCourtPointTap: (_) => accepted++,
        onInvalidCourtPoint: (_) => invalid++,
      ),
    );
    await tester.tapAt(position(tester, .5, .9));
    expect(accepted, 0);
    expect(invalid, 1);
    final rect = tester.getRect(find.byType(CourtView));
    await tester.tapAt(rect.topLeft + const Offset(5, 20));
    expect(invalid, 1);
    expect(accepted, 0);
    await tester.tapAt(position(tester, .5, .4));
    expect(accepted, 1);
  });

  testWidgets('active supplement takes priority over an existing shot marker', (
    tester,
  ) async {
    var pointTaps = 0;
    var markerTaps = 0;
    await mount(
      tester,
      CourtView(
        shotLocations: [
          ScoringShotLocation(
            id: 'old',
            eventId: 'old-event',
            side: TeamSide.red,
            points: 3,
            point: CourtPoint(x: .5, y: .8),
            isLocked: true,
          ),
        ],
        activeRegion: CourtRegion.outsideArc,
        reduceMotion: true,
        onCourtPointTap: (_) => pointTaps++,
        onShotLocationTap: (_) => markerTaps++,
      ),
    );
    await tester.tapAt(position(tester, .5, .8));
    expect(pointTaps, 1);
    expect(markerTaps, 0);
  });

  testWidgets(
    'free throw hit band is generous but never eligible outside arc',
    (tester) async {
      final selections = <CourtSelection>[];
      await mount(
        tester,
        CourtView(shotLocations: const [], onCourtSelectionTap: selections.add),
      );
      await tester.tapAt(position(tester, .5, 5.8 / 14) + const Offset(0, 20));
      await tester.tapAt(position(tester, .5, .9));
      expect(selections[0].freeThrowEligible, isTrue);
      expect(selections[1].freeThrowEligible, isFalse);
    },
  );

  testWidgets('keyboard moves a visible draft before explicit confirmation', (
    tester,
  ) async {
    final selections = <CourtSelection>[];
    await mount(
      tester,
      CourtView(
        shotLocations: const [],
        activeRegion: CourtRegion.outsideArc,
        reduceMotion: true,
        onCourtSelectionTap: selections.add,
      ),
    );
    final focus = tester.widget<FocusableActionDetector>(
      find.byKey(const Key('court-keyboard-target')),
    );
    focus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(selections, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selections.single.point.x, greaterThan(.5));
    expect(CourtGeometry.isOutsideArc(selections.single.point), isTrue);
  });

  testWidgets(
    'point eligibility disables individual actions and labels free throw',
    (tester) async {
      final values = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 650,
              child: ScoreSidePanel(
                side: TeamSide.blue,
                name: 'Blue',
                score: 0,
                fouls: 0,
                onScore: values.add,
                onMiss: () {},
                enabledScorePoints: const {1, 2},
                scoreButtonLabels: const {1: '罚球 +1'},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('blue-score-3')));
      expect(values, isEmpty);
      await tester.tap(find.byKey(const Key('blue-score-1')));
      expect(values, [1]);
      expect(find.text('罚球 +1'), findsOneWidget);
    },
  );

  testWidgets(
    'reduced motion holds spotlight and clearing region stops pulse',
    (tester) async {
      await mount(
        tester,
        const CourtView(
          shotLocations: [],
          activeRegion: CourtRegion.outsideArc,
          reduceMotion: true,
        ),
      );
      CourtPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(CourtView),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as CourtPainter;
      final staticValue = painter().regionPulse!.value;
      await tester.pump(const Duration(milliseconds: 700));
      expect(painter().regionPulse!.value, staticValue);
      await mount(
        tester,
        const CourtView(
          shotLocations: [],
          activeRegion: CourtRegion.outsideArc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(painter().regionPulse!.value, isNot(staticValue));
      await mount(tester, const CourtView(shotLocations: []));
      await tester.pumpAndSettle();
      expect(painter().activeRegion, isNull);
    },
  );

  testWidgets(
    'read-only free throw display never creates an editable location',
    (tester) async {
      var accepted = 0;
      await mount(
        tester,
        CourtView(
          shotLocations: const [],
          mode: CourtViewMode.readOnly,
          freeThrowMarkers: const [
            FreeThrowCourtMarker(eventId: 'ft', side: TeamSide.blue),
          ],
          onCourtPointTap: (_) => accepted++,
        ),
      );
      await tester.tapAt(position(tester, .5, 5.8 / 14));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(CourtView),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as CourtPainter;
      expect(accepted, 0);
      expect(painter.shotLocations, isEmpty);
      expect(painter.freeThrowMarkers.single.eventId, 'ft');
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'English free throw label retains +1 at ${scale * 100}% in narrow rail',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SizedBox(
                  width: 88,
                  height: 411,
                  child: ScoreSidePanel(
                    side: TeamSide.blue,
                    name: 'Blue',
                    score: 0,
                    fouls: 0,
                    onScore: (_) {},
                    onMiss: () {},
                    scoreButtonLabels: const {1: 'Free throw +1'},
                  ),
                ),
              ),
            ),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('Free throw +1'),
        );
        final suffix = paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 11, extentOffset: 13),
        );
        expect(suffix, isNotEmpty);
        expect(
          tester.getSize(find.byKey(const Key('blue-score-1'))).height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
