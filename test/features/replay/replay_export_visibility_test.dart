import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/replay_image_exporter.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';

import '../../support/golden_fonts.dart';

const _redName = 'River · 红方本场长姓名 · North Riverside Basketball Club';
const _blueName = 'Jordan · 蓝方本场长姓名 · South Waterfront Basketball Club';

void main() {
  setUpAll(loadHoopitoGoldenFonts);

  for (final locale in const [Locale('zh'), Locale('en')]) {
    for (final brightness in Brightness.values) {
      for (final coverage in const [
        TrackingCoverage.scoresOnly,
        TrackingCoverage.shotAttempts,
      ]) {
        final name =
            '${locale.languageCode}-${brightness.name}-${coverage.name}';
        testWidgets('report PNG paints all metrics and long names: $name', (
          tester,
        ) async {
          await _openReport(
            tester,
            locale: locale,
            brightness: brightness,
            coverage: coverage,
          );
          final report = find.byKey(const Key('replay-export-summary'));
          final l10n = AppLocalizations.of(tester.element(report))!;
          final capture = await _captureReport(tester, name);

          // Check the actual exported pixels before checking text semantics.
          // A widget can exist below a clipped GridView without appearing in PNG.
          _expectTextPainted(tester, capture, l10n.v2CoverageTitle);
          _expectTextPainted(
            tester,
            capture,
            coverage == TrackingCoverage.scoresOnly
                ? l10n.v2CoverageScores
                : l10n.v2CoverageComplete,
          );
          for (final text in [
            _redName,
            _blueName,
            l10n.replayDuration,
            l10n.v2LocationScope,
            '3/5',
            l10n.v2FieldGoalPercentage,
            l10n.v2FreeThrowPercentage,
            l10n.replayExportLeadChanges,
            l10n.replayExportLargestLead,
            l10n.v2RecordedSample,
          ]) {
            _expectTextPainted(tester, capture, text);
          }
          final percentages = find.descendant(
            of: report,
            matching: find.textContaining('%'),
          );
          if (coverage == TrackingCoverage.scoresOnly) {
            // FG%/FT% are labels, but incomplete recording has no percentage value.
            expect(
              find.descendant(of: report, matching: find.text('80%')),
              findsNothing,
            );
            expect(
              find.descendant(of: report, matching: find.text('50%')),
              findsNothing,
            );
          } else {
            expect(percentages, findsWidgets);
            _expectTextPainted(tester, capture, '80%');
            _expectTextPainted(tester, capture, '50%');
          }
          _expectAllTextInsideReport(tester, capture);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets(
        'zero-attempt PNG shows no data: ${locale.languageCode}-${brightness.name}',
        (tester) async {
          await _openReport(
            tester,
            locale: locale,
            brightness: brightness,
            coverage: TrackingCoverage.shotAttempts,
            zeroAttempts: true,
          );
          final report = find.byKey(const Key('replay-export-summary'));
          final l10n = AppLocalizations.of(tester.element(report))!;
          final capture = await _captureReport(
            tester,
            '${locale.languageCode}-${brightness.name}-zero',
          );
          _expectTextPainted(tester, capture, l10n.v2CoverageTitle);
          _expectTextPainted(tester, capture, l10n.v2LocationScope);
          final locationLabel = find.descendant(
            of: report,
            matching: find.text(l10n.v2LocationScope),
          );
          final metric = find
              .ancestor(of: locationLabel, matching: find.byType(DecoratedBox))
              .first;
          expect(
            find.descendant(of: metric, matching: find.text(l10n.replayNoData)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: report, matching: find.text('0/0')),
            findsNothing,
          );
          _expectAllTextInsideReport(tester, capture);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final locale in const [Locale('zh'), Locale('en')]) {
    testWidgets(
      'landscape dialog shares and cancels at 200%: ${locale.languageCode}',
      (tester) async {
        await _openReport(
          tester,
          locale: locale,
          brightness: Brightness.dark,
          coverage: TrackingCoverage.shotAttempts,
        );
        final reference = await _captureReport(
          tester,
          '${locale.languageCode}-reference-100',
        );
        Uint8List? shared;
        await _openReport(
          tester,
          locale: locale,
          brightness: Brightness.dark,
          coverage: TrackingCoverage.shotAttempts,
          size: const Size(600, 400),
          scale: 2,
          onShare: (bytes, matchId) async {
            expect(matchId, 'export-visible');
            shared = bytes;
          },
        );
        final report = find.byKey(const Key('replay-export-summary'));
        final l10n = AppLocalizations.of(tester.element(report))!;
        final capture = await _captureReport(
          tester,
          '${locale.languageCode}-landscape-200',
        );
        _expectAllTextInsideReport(tester, capture);
        _expectTextPainted(tester, capture, l10n.v2CoverageTitle);
        expect(capture.image.width, reference.image.width);
        expect(capture.image.height, reference.image.height);
        final share = find.byKey(const Key('replay-export-confirm'));
        final cancel = find.widgetWithText(TextButton, l10n.cancelAction);
        for (final action in [share, cancel]) {
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getRect(action).bottom, lessThanOrEqualTo(400));
          expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(shared, isNull);
        expect(find.byType(Dialog), findsNothing);

        await tester.tap(find.byKey(const Key('open-report')));
        await tester.pumpAndSettle();
        await tester.tap(share);
        await _pumpUntil(tester, () => shared != null);
        await tester.pumpAndSettle();
        final codec = await tester.runAsync(
          () => ui.instantiateImageCodec(shared!),
        );
        final frame = await tester.runAsync(codec!.getNextFrame);
        expect(frame!.image.width, 2700);
        expect(frame.image.height, (capture.boundary.size.height * 3).ceil());
        frame.image.dispose();
        codec.dispose();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _openReport(
  WidgetTester tester, {
  required Locale locale,
  required Brightness brightness,
  required TrackingCoverage coverage,
  bool zeroAttempts = false,
  Size size = const Size(1000, 700),
  double scale = 1,
  Future<void> Function(Uint8List, String)? onShare,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = _controller(coverage, zeroAttempts: zeroAttempts);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: buildHoopitoTheme(brightness: brightness),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('open-report'),
              onPressed: () => showMatchReportDialog(
                context,
                controller: controller,
                onShare: onShare ?? (_, _) async {},
              ),
              child: const Text('Report'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-report')));
  await tester.pumpAndSettle();
}

ReplayController _controller(
  TrackingCoverage coverage, {
  required bool zeroAttempts,
}) {
  final complete = coverage == TrackingCoverage.shotAttempts;
  return ReplayController(
    data: ReplayMatchData(
      matchId: 'export-visible',
      redName: _redName,
      blueName: _blueName,
      redScore: zeroAttempts ? 0 : 11,
      blueScore: zeroAttempts ? 0 : 8,
      duration: const Duration(minutes: 17, seconds: 24),
      // Controller's location count is deliberately not the analytics count.
      // The report must use the same confirmed-FG sample as other analytics UI.
      events: zeroAttempts
          ? const []
          : [
              ReplayEventData(
                id: 'visible-location',
                kind: ReplayEventKind.score,
                side: TeamSide.red,
                points: 2,
                elapsed: const Duration(seconds: 4),
                shotPoint: CourtPoint(x: .3, y: .7),
              ),
            ],
      analytics: MatchAnalytics(
        scoringFlow: const [],
        largestLeadSide: zeroAttempts ? null : TeamSide.red,
        largestLeadPoints: zeroAttempts ? 0 : 3,
        leadChanges: zeroAttempts ? 0 : 3,
        madeShotCount: zeroAttempts ? 0 : 5,
        missedShotCount: zeroAttempts ? 0 : 2,
        shootingPercentage: complete && !zeroAttempts ? .8 : 0,
        recordedShootingPercentage: complete && !zeroAttempts ? .8 : null,
        shootingPercentageIsTrustworthy: complete && !zeroAttempts,
        trackingCoverage: coverage,
        fieldGoalMadeCount: zeroAttempts ? 0 : 4,
        fieldGoalAttemptCount: zeroAttempts ? 0 : 5,
        freeThrowMadeCount: zeroAttempts ? 0 : 1,
        freeThrowAttemptCount: zeroAttempts ? 0 : 2,
        confirmedLocationCount: zeroAttempts ? 0 : 3,
        locationCoverage: zeroAttempts ? 0 : 3 / 5,
        keyPossessions: const [],
      ),
    ),
  );
}

class _Capture {
  const _Capture(this.boundary, this.image, this.rgba, this.background);
  final RenderRepaintBoundary boundary;
  final ui.Image image;
  final ByteData rgba;
  final Color background;
}

Future<_Capture> _captureReport(WidgetTester tester, String name) async {
  final report = find.byKey(const Key('replay-export-summary'));
  RepaintBoundary? widget;
  tester.element(report).visitAncestorElements((element) {
    if (element.widget is RepaintBoundary) {
      widget = element.widget as RepaintBoundary;
      return false;
    }
    return true;
  });
  final boundaryKey = widget!.key! as GlobalKey;
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(
    () => ReplayImageExporter.capture(boundaryKey),
  );
  final codec = await tester.runAsync(() => ui.instantiateImageCodec(bytes!));
  final frame = await tester.runAsync(codec!.getNextFrame);
  codec.dispose();
  final image = frame!.image;
  addTearDown(image.dispose);
  final rgba = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  expect(image.width, 2700);
  expect(image.height, (boundary.size.height * 3).ceil());
  expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  const evidence = String.fromEnvironment('HOOPITO_EXPORT_EVIDENCE');
  if (evidence.isNotEmpty) {
    await tester.runAsync(() async {
      final directory = await Directory(evidence).create(recursive: true);
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
    });
  }
  return _Capture(
    boundary,
    image,
    rgba!,
    Theme.of(tester.element(report)).colorScheme.surface,
  );
}

void _expectTextPainted(WidgetTester tester, _Capture capture, String text) {
  final finder = find.descendant(
    of: find.byKey(const Key('replay-export-summary')),
    matching: find.text(text),
  );
  expect(finder, findsOneWidget, reason: 'Export text: $text');
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final bounds = MatrixUtils.transformRect(
    paragraph.getTransformTo(capture.boundary),
    paragraph.paintBounds,
  );
  _expectBounds(capture, paragraph, bounds, text);
  final background = capture.background.toARGB32();
  var ink = 0;
  for (var y = (bounds.top * 3).ceil(); y < (bounds.bottom * 3).floor(); y++) {
    for (
      var x = (bounds.left * 3).ceil();
      x < (bounds.right * 3).floor();
      x++
    ) {
      final offset = (y * capture.image.width + x) * 4;
      final red = capture.rgba.getUint8(offset);
      final green = capture.rgba.getUint8(offset + 1);
      final blue = capture.rgba.getUint8(offset + 2);
      if ((red - ((background >> 16) & 255)).abs() > 20 ||
          (green - ((background >> 8) & 255)).abs() > 20 ||
          (blue - (background & 255)).abs() > 20) {
        ink++;
      }
    }
  }
  expect(
    ink,
    greaterThan(5),
    reason: 'PNG must paint text, not just lay it out: $text',
  );
}

void _expectAllTextInsideReport(WidgetTester tester, _Capture capture) {
  final finder = find.descendant(
    of: find.byKey(const Key('replay-export-summary')),
    matching: find.byType(RichText),
  );
  for (final element in finder.evaluate()) {
    final paragraph = element.findRenderObject()! as RenderParagraph;
    final bounds = MatrixUtils.transformRect(
      paragraph.getTransformTo(capture.boundary),
      paragraph.paintBounds,
    );
    _expectBounds(capture, paragraph, bounds, paragraph.text.toPlainText());
  }
}

void _expectBounds(
  _Capture capture,
  RenderParagraph paragraph,
  Rect bounds,
  String text,
) {
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: 'No truncated export text: $text',
  );
  expect(bounds.left, greaterThanOrEqualTo(0), reason: text);
  expect(bounds.top, greaterThanOrEqualTo(0), reason: text);
  expect(
    bounds.right,
    lessThanOrEqualTo(capture.boundary.size.width),
    reason: text,
  );
  expect(
    bounds.bottom,
    lessThanOrEqualTo(capture.boundary.size.height),
    reason: text,
  );
  RenderObject child = paragraph;
  RenderObject? ancestor = paragraph.parent;
  while (ancestor != null && ancestor != capture.boundary) {
    final clip = ancestor.describeApproximatePaintClip(child);
    if (clip != null) {
      final clipBounds = MatrixUtils.transformRect(
        ancestor.getTransformTo(capture.boundary),
        clip,
      );
      expect(
        clipBounds.contains(bounds.topLeft),
        isTrue,
        reason: 'Clipped export text: $text',
      );
      expect(
        clipBounds.contains(bounds.bottomRight - const Offset(.01, .01)),
        isTrue,
        reason: 'Clipped export text: $text',
      );
    }
    child = ancestor;
    ancestor = ancestor.parent;
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100 && !ready(); frame++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(() => Future<void>(() {}));
  }
  expect(ready(), isTrue, reason: 'Report sharing did not complete');
}
