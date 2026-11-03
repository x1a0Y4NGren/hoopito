import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/widgets/court_painter.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';
import 'package:hoopito/features/scoring/widgets/score_side_panel.dart';

void main() {
  testWidgets('court view accepts hidden durable ids and transient markers', (
    tester,
  ) async {
    final point = CourtPoint(x: 0.3, y: 0.4);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourtView(
            shotLocations: [
              ScoringShotLocation(
                id: 'shot-1',
                eventId: 'event-1',
                side: TeamSide.blue,
                points: 2,
                point: point,
                isLocked: true,
              ),
            ],
            hiddenShotLocationIds: const {'shot-1'},
            transientMarkers: [
              TransientShotMarker(
                id: 'shot-1',
                point: point,
                side: TeamSide.blue,
              ),
            ],
          ),
        ),
      ),
    );

    final court = tester.widget<CourtView>(find.byType(CourtView));
    expect(court.hiddenShotLocationIds, contains('shot-1'));
    expect(court.transientMarkers.single.id, 'shot-1');
  });

  testWidgets('hidden markers do not intercept a new court point tap', (
    tester,
  ) async {
    var courtTaps = 0;
    var markerTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 280,
            child: CourtView(
              shotLocations: [
                ScoringShotLocation(
                  id: 'hidden-miss',
                  eventId: 'hidden-event',
                  side: TeamSide.blue,
                  points: 0,
                  point: CourtPoint(x: 0.5, y: 0.5),
                  isLocked: true,
                ),
              ],
              hiddenShotLocationIds: const {'hidden-miss'},
              onCourtPointTap: (_) => courtTaps++,
              onShotLocationTap: (_) => markerTaps++,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.byType(CourtView)));
    expect(courtTaps, 1);
    expect(markerTaps, 0);
  });

  test('miss markers use a white fill and a team-colored cross', () async {
    const teamBlue = Color(0xFF1769FF);
    const teamRed = Color(0xFFE53935);
    const markerRing = Color(0xFF202124);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(300, 280);
    final bluePoint = CourtPoint(x: 0.2, y: 0.4);
    final redPoint = CourtPoint(x: 0.8, y: 0.4);
    final madePoint = CourtPoint(x: 0.2, y: 0.7);
    final painter = CourtPainter(
      shotLocations: [
        ScoringShotLocation(
          id: 'blue-miss',
          eventId: 'blue-miss-event',
          side: TeamSide.blue,
          points: 0,
          point: bluePoint,
          isLocked: true,
        ),
        ScoringShotLocation(
          id: 'red-miss',
          eventId: 'red-miss-event',
          side: TeamSide.red,
          points: 0,
          point: redPoint,
          isLocked: true,
        ),
        ScoringShotLocation(
          id: 'blue-made',
          eventId: 'blue-made-event',
          side: TeamSide.blue,
          points: 2,
          point: madePoint,
          isLocked: true,
        ),
      ],
      teamBlueColor: teamBlue,
      teamRedColor: teamRed,
      markerRingColor: markerRing,
    );
    painter.paint(canvas, size);
    final image = await recorder.endRecording().toImage(300, 280);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);
    expect(
      _pixelAt(bytes!, width: 300, x: 60, y: 116).toARGB32(),
      Colors.white.toARGB32(),
    );
    expect(
      _pixelAt(bytes, width: 300, x: 240, y: 116).toARGB32(),
      Colors.white.toARGB32(),
    );
    expect(_pixelAt(bytes, width: 300, x: 60, y: 196), teamBlue);
    expect(_pixelAt(bytes, width: 300, x: 60, y: 112), teamBlue);
    expect(_pixelAt(bytes, width: 300, x: 240, y: 112), teamRed);
    image.dispose();
  });

  test('court painter renders an eraser presentation marker', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(320, 280);
    final painter = CourtPainter(
      eraserMarkers: [
        EraserShotMarker(
          id: 'erased-shot',
          point: CourtPoint(x: 0.35, y: 0.45),
          side: TeamSide.blue,
          progress: 0.5,
        ),
      ],
    );

    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    expect(picture, isNotNull);
    picture.dispose();
  });

  test('court painter accepts semantic flat-court and eraser colors', () async {
    const surface = Color(0xFF123456);
    const accent = Color(0xFF00FF00);
    const eraser = Color(0xFFFEDCBA);
    const teamBlue = Color(0xFF00FFFF);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(300, 280);
    final painter = CourtPainter(
      shotLocations: [
        ScoringShotLocation(
          id: 'selected',
          eventId: 'selected-event',
          side: TeamSide.blue,
          points: 2,
          point: CourtPoint(x: 0.5, y: 0.5),
          isLocked: true,
        ),
      ],
      highlightedShotLocationId: 'selected',
      eraserMarkers: [
        EraserShotMarker(
          id: 'erased',
          point: CourtPoint(x: 0.25, y: 0.75),
          side: TeamSide.red,
          progress: 0,
        ),
      ],
      surfaceColor: surface,
      lineColor: Colors.white,
      accentColor: accent,
      eraserColor: eraser,
      teamBlueColor: teamBlue,
    );
    painter.paint(canvas, size);
    final image = await recorder.endRecording().toImage(300, 280);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);
    expect(_pixelAt(bytes!, width: 300, x: 1, y: 1), surface);
    final selectedRule = _pixelAt(bytes, width: 300, x: 163, y: 140);
    expect(selectedRule, accent);
    expect(_pixelAt(bytes, width: 300, x: 150, y: 140), teamBlue);
    final eraserRule = _pixelAt(bytes, width: 300, x: 83, y: 210);
    expect(eraserRule, eraser);
    image.dispose();
  });
  testWidgets('court prompt is announced while a score location is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourtView(
            shotLocations: const [],
            locationPrompt: '补充红方 +2 落点 · 8 秒',
          ),
        ),
      ),
    );

    expect(find.text('补充红方 +2 落点 · 8 秒'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
  });

  test('half court geometry preserves FIBA half-court aspect ratio', () {
    final court = HalfCourtGeometry.courtRectForSize(const Size(700, 360));

    expect(court.width / court.height, closeTo(15 / 14, 0.001));
    expect(court.height, 360);
  });

  test('pointFromLocal maps through the visible court rectangle', () {
    const size = Size(700, 360);
    final court = HalfCourtGeometry.courtRectForSize(size);
    final center = pointFromLocal(court.center, size);

    expect(center.x, closeTo(0.5, 0.001));
    expect(center.y, closeTo(0.5, 0.001));
  });

  test('pointFromLocal clamps positions into normalized court bounds', () {
    final point = pointFromLocal(const Offset(250, -20), const Size(200, 100));

    expect(point.x, 1);
    expect(point.y, 0);
  });

  testWidgets('court prompt remains usable in narrow layouts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 260,
            child: CourtView(
              shotLocations: const [],
              locationPrompt: '补充红方 +2 落点 · 8 秒',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('补充红方 +2 落点 · 8 秒'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
  });

  testWidgets('editable court exposes an accessible center-point tap', (
    tester,
  ) async {
    CourtPoint? tappedPoint;
    final semanticsHandle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 280,
              child: CourtView(
                key: const Key('accessible-court'),
                shotLocations: const [],
                onCourtPointTap: (point) => tappedPoint = point,
                mode: CourtViewMode.editable,
              ),
            ),
          ),
        ),
      );
      final editableCourt = find.semantics.byLabel('篮球场投篮位置编辑区');
      final semantics = tester.getSemantics(
        find.descendant(
          of: find.byKey(const Key('accessible-court')),
          matching: find.byType(Semantics),
        ),
      );
      expect(
        semantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );

      tester.semantics.tap(editableCourt);
      expect(tappedPoint, isNotNull);
      expect(tappedPoint!.x, closeTo(0.5, 0.01));
      expect(tappedPoint!.y, closeTo(0.5, 0.01));
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('accessible court tap updates a pending location', (
    tester,
  ) async {
    CourtPoint? updatedPoint;
    final semanticsHandle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 280,
              child: CourtView(
                key: const Key('accessible-pending-court'),
                shotLocations: const [],
                pendingLocation: PendingShotLocation(
                  eventId: 'pending',
                  side: TeamSide.blue,
                  points: 2,
                  point: CourtPoint(x: 0.2, y: 0.2),
                ),
                onPendingLocationChanged: (point) => updatedPoint = point,
                mode: CourtViewMode.editable,
              ),
            ),
          ),
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('篮球场投篮位置编辑区'));
      expect(updatedPoint, isNotNull);
      expect(updatedPoint!.x, closeTo(0.5, 0.01));
      expect(updatedPoint!.y, closeTo(0.5, 0.01));
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets(
    'score side panel does not overflow at 200 percent in a narrow column',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 88,
                height: 411,
                child: ScoreSidePanel(
                  side: TeamSide.blue,
                  name: 'Blue',
                  score: 12,
                  fouls: 1,
                  onScore: (_) {},
                  missEnabled: true,
                  onMiss: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Color _pixelAt(
  ByteData bytes, {
  required int width,
  required int x,
  required int y,
}) {
  final offset = (y * width + x) * 4;
  return Color.fromARGB(
    255,
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
}
