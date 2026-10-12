import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/motion/scoring_motion.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:lottie/lottie.dart';

ShotLocationCommitReceipt receipt(String id, {double x = .5, double y = .5}) {
  return ShotLocationCommitReceipt(
    eventId: 'event-$id',
    shotLocationId: 'location-$id',
    side: TeamSide.blue,
    points: 2,
    point: CourtPoint(x: x, y: y),
    source: ShotLocationCommitSource.courtFirst,
  );
}

void main() {
  test('motion theme exposes standard and accelerated timings', () {
    final light = const HoopitoMotionTheme.light();
    final dark = const HoopitoMotionTheme.dark();
    expect(light.scoreFlight, const Duration(milliseconds: 480));
    expect(light.impact, const Duration(milliseconds: 180));
    expect(light.acceleratedScoreFlight, const Duration(milliseconds: 320));
    expect(light.acceleratedImpact, const Duration(milliseconds: 120));
    expect(dark.acceleratedScoreFlight, light.acceleratedScoreFlight);
    expect(light, light.copyWith());
    expect(light.hashCode, light.copyWith().hashCode);
    expect(
      light
          .copyWith(acceleratedImpact: const Duration(seconds: 1))
          .acceleratedImpact,
      const Duration(seconds: 1),
    );
    expect(
      light
          .lerp(
            light.copyWith(acceleratedImpact: const Duration(seconds: 1)),
            .5,
          )
          .acceleratedImpact,
      const Duration(milliseconds: 560),
    );
  });

  testWidgets(
    'team fill delegate reaches bundled fill and changes composition color',
    (tester) async {
      final coordinator = ScoringMotionCoordinator();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(brightness: Brightness.light),
          home: ScoringMotionOverlay(coordinator: coordinator),
        ),
      );
      coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('tint'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      );
      await tester.pump();
      final builder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      final delegate = builder.delegates!.values!.single;
      expect(delegate.keyPath, ['**', 'teamFill', 'teamFill', 'teamFill']);
      expect(
        delegate.value,
        teamColorForScheme(TeamSide.blue, buildHoopitoTheme().colorScheme),
      );

      final data = await rootBundle.load('assets/animations/paint_ball.json');
      final composition = await LottieComposition.fromByteData(data);
      final json =
          jsonDecode(utf8.decode(data.buffer.asUint8List()))
              as Map<String, dynamic>;
      final originalColor =
          (((json['layers'] as List).first as Map)['shapes'] as List)
                  .firstWhere((shape) => shape['ty'] == 'gr')['it']
                  .firstWhere((shape) => shape['ty'] == 'fl')['c']['k']
              as List;
      expect(originalColor, [1, .478, .102, 1]);
      final drawable = LottieDrawable(composition);
      Color? callbackColor;
      final tintedDelegates = LottieDelegates(
        values: [
          ValueDelegate.color(
            ['**', 'teamFill', 'teamFill', 'teamFill'],
            callback: (_) {
              callbackColor = Colors.blue;
              return Colors.blue;
            },
          ),
        ],
      );
      drawable.delegates = tintedDelegates;
      drawable.setProgress(0);
      final recorder = ui.PictureRecorder();
      drawable.draw(Canvas(recorder), const Rect.fromLTWH(0, 0, 128, 128));
      recorder.endRecording();
      expect(drawable.delegatesHash(), isNot(0));
      expect(callbackColor, Colors.blue);
      coordinator.dispose();
    },
  );

  test('bundled ball and splash draw delegates resolve blue and red', () async {
    final theme = buildHoopitoTheme();
    for (final side in TeamSide.values) {
      final expected = teamColorForScheme(side, theme.colorScheme);
      for (final asset in [
        'assets/animations/paint_ball.json',
        'assets/animations/paint_splash.json',
      ]) {
        final data = await rootBundle.load(asset);
        final composition = await LottieComposition.fromByteData(data);
        Color? callbackColor;
        final drawable = LottieDrawable(composition);
        drawable.delegates = LottieDelegates(
          values: [
            ValueDelegate.color(
              ['**', 'teamFill', 'teamFill', 'teamFill'],
              callback: (_) {
                callbackColor = expected;
                return expected;
              },
            ),
          ],
        );
        drawable.setProgress(0);
        final recorder = ui.PictureRecorder();
        drawable.draw(Canvas(recorder), const Rect.fromLTWH(0, 0, 180, 180));
        recorder.endRecording();
        expect(callbackColor, expected, reason: '$side $asset');
        expect(callbackColor, isNot(HoopitoColors.orange));
      }
    }
  });

  test('cubic geometry samples exact endpoints and bounded controls', () {
    final path = ScoringMotionPath.build(
      source: const Offset(80, 520),
      destination: const Offset(680, 180),
      safeWorkspace: const Rect.fromLTWH(24, 24, 712, 520),
    );
    expect(
      (path.sample(0).position - const Offset(80, 520)).distance,
      lessThanOrEqualTo(1),
    );
    expect(path.sample(.5).position.dx.isFinite, isTrue);
    expect(
      (path.sample(1).position - const Offset(680, 180)).distance,
      lessThanOrEqualTo(1),
    );
    for (final point in [path.control1, path.control2]) {
      expect(path.safeWorkspace.contains(point), isTrue);
    }
    final sample = path.sample(1);
    expect(sample.trail.length, lessThanOrEqualTo(12));
    for (var i = 1; i < sample.trail.length; i++) {
      expect(
        sample.trail[i].opacity,
        lessThanOrEqualTo(sample.trail[i - 1].opacity),
      );
    }
    expect(sample.tangent.vector.distance.isFinite, isTrue);
  });

  test('broadcast flight uses a compact arc and a restrained trail', () {
    final top = ScoringMotionPath.build(
      source: const Offset(100, 300),
      destination: const Offset(300, 100),
      safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
    );
    expect(top.control1.dx, 100);
    expect(top.control1.dy, closeTo(260.40202, .00001));
    expect(top.control2.dx, 300);
    expect(top.control2.dy, closeTo(60.40202, .00001));
    expect(top.sample(.5).trail, hasLength(6));

    final side = ScoringMotionPath.build(
      source: const Offset(20, 100),
      destination: const Offset(100, 120),
      safeWorkspace: const Rect.fromLTWH(0, 80, 120, 120),
    );
    expect(side.control1, const Offset(52, 100));
    expect(side.control2, const Offset(120, 120));
    expect(side.sample(.5).trail, hasLength(6));
  });

  testWidgets('impact overlay has one compact composition spread owner', (
    tester,
  ) async {
    final coordinator = ScoringMotionCoordinator();
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringMotionOverlay(
          coordinator: coordinator,
          assetBuilder: (context, active, color) => SizedBox(
            key: Key(
              active.inImpact ? 'impact-spread-owner' : 'flight-ball-owner',
            ),
          ),
        ),
      ),
    );
    coordinator.submit(
      ScoringMotionEvent(
        receipt: receipt('one-spread'),
        sourceButton: const Offset(20, 20),
        courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
        safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
      ),
    );
    coordinator.advance(const Duration(milliseconds: 480));
    await tester.pump();
    final canvas = TestRecordingCanvas();
    final customPaint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(ScoringMotionOverlay),
        matching: find.byType(CustomPaint),
      ),
    );
    (customPaint.painter! as ScoringMotionPainter).paint(
      canvas,
      const Size(400, 400),
    );

    expect(find.byKey(const Key('impact-spread-owner')), findsOneWidget);
    expect(
      canvas.invocations.where(
        (call) => call.invocation.memberName == #drawCircle,
      ),
      isEmpty,
    );
    coordinator.dispose();
  });

  test(
    'coordinator preserves FIFO order and accelerates after backlog three',
    () {
      final completed = <String>[];
      final coordinator = ScoringMotionCoordinator(
        motionTheme: const HoopitoMotionTheme.light(),
        onComplete: (event) => completed.add(event.receipt.eventId),
      );
      for (var i = 0; i < 5; i++) {
        coordinator.submit(
          ScoringMotionEvent(
            receipt: receipt('$i'),
            sourceButton: const Offset(20, 20),
            courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
            safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
          ),
        );
      }
      expect(coordinator.pendingCount, 5);
      expect(coordinator.queuedEvents.map((event) => event.receipt.eventId), [
        'event-1',
        'event-2',
        'event-3',
        'event-4',
      ]);
      expect(
        coordinator.active!.timing.flight,
        const Duration(milliseconds: 480),
      );
      coordinator.advance(const Duration(milliseconds: 760));
      expect(
        coordinator.active!.timing.flight,
        const Duration(milliseconds: 320),
      );
      coordinator.advance(const Duration(milliseconds: 440));
      expect(completed, ['event-0', 'event-1']);
      coordinator.advance(const Duration(seconds: 10));
      expect(completed, [
        'event-0',
        'event-1',
        'event-2',
        'event-3',
        'event-4',
      ]);
      coordinator.dispose();
    },
  );

  test('completion callback submission preserves an existing FIFO queue', () {
    final completed = <String>[];
    late ScoringMotionCoordinator coordinator;
    coordinator = ScoringMotionCoordinator(
      onComplete: (event) {
        completed.add(event.id);
        if (event.id == 'event-0') {
          coordinator.submit(
            ScoringMotionEvent(
              receipt: receipt('reentrant'),
              sourceButton: const Offset(20, 20),
              courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
              safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
            ),
          );
        }
      },
    );
    for (var i = 0; i < 3; i++) {
      coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('$i'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      );
    }
    coordinator.advance(const Duration(seconds: 10));
    expect(completed, ['event-0', 'event-1', 'event-2', 'event-reentrant']);
    coordinator.dispose();
  });

  test('completion callback may dispose without restarting or notifying', () {
    late ScoringMotionCoordinator coordinator;
    coordinator = ScoringMotionCoordinator(
      onComplete: (_) => coordinator.dispose(),
    );
    coordinator.submit(
      ScoringMotionEvent(
        receipt: receipt('dispose-callback'),
        sourceButton: const Offset(20, 20),
        courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
        safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
      ),
    );
    expect(
      () => coordinator.advance(const Duration(seconds: 2)),
      returnsNormally,
    );
    expect(coordinator.pendingCount, 0);
  });

  test(
    'impact callback fires when flight starts, including a large time step',
    () {
      final impacts = <String>[];
      final completed = <String>[];
      final coordinator = ScoringMotionCoordinator(
        onImpact: (event) => impacts.add(event.id),
        onComplete: (event) => completed.add(event.id),
      );
      coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('impact-start'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      );

      coordinator.advance(const Duration(milliseconds: 480));
      expect(impacts, ['event-impact-start']);
      expect(completed, isEmpty);
      coordinator.advance(const Duration(seconds: 1));
      expect(impacts, ['event-impact-start']);
      expect(completed, ['event-impact-start']);
      coordinator.dispose();
    },
  );

  test(
    'duplicate IDs are rejected before disabled and fallback fast paths',
    () {
      for (final mode in [
        ScoringMotionMode.disabled,
        ScoringMotionMode.standard,
      ]) {
        final completed = <String>[];
        final coordinator = ScoringMotionCoordinator(
          mode: mode,
          onComplete: (event) => completed.add(event.id),
        );
        final first = ScoringMotionEvent(
          receipt: receipt('duplicate-$mode'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
          assetAvailable: mode == ScoringMotionMode.disabled,
        );
        final second = ScoringMotionEvent(
          receipt: receipt('duplicate-$mode'),
          sourceButton: const Offset(30, 30),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
          assetAvailable: mode == ScoringMotionMode.disabled,
        );
        expect(coordinator.submit(first), isTrue);
        expect(coordinator.submit(second), isFalse);
        expect(completed, ['event-duplicate-$mode']);
        coordinator.dispose();
      }
    },
  );

  test('fallback disposal prevents completion callback', () {
    var completions = 0;
    late ScoringMotionCoordinator coordinator;
    coordinator = ScoringMotionCoordinator(
      onFallback: (_) => coordinator.dispose(),
      onComplete: (_) => completions++,
    );
    expect(
      () => coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('fallback-dispose'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
          assetAvailable: false,
        ),
      ),
      returnsNormally,
    );
    expect(completions, 0);
  });

  test('throwing completion callback resets dispatch state', () {
    late ScoringMotionCoordinator coordinator;
    coordinator = ScoringMotionCoordinator(
      onComplete: (_) => throw StateError('completion failed'),
    );
    coordinator.submit(
      ScoringMotionEvent(
        receipt: receipt('throws'),
        sourceButton: const Offset(20, 20),
        courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
        safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
      ),
    );
    expect(
      () => coordinator.advance(const Duration(milliseconds: 760)),
      throwsA(isA<StateError>()),
    );
    expect(
      coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('after-throw'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      ),
      isTrue,
    );
    expect(coordinator.active!.event.id, 'event-after-throw');
    coordinator.dispose();
  });

  test('throwing fallback callback resets dispatch state', () {
    final coordinator = ScoringMotionCoordinator(
      onFallback: (_) => throw StateError('fallback failed'),
    );
    expect(
      () => coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('fallback-throws'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
          assetAvailable: false,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('after-fallback-throw'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      ),
      isTrue,
    );
    expect(coordinator.active!.event.id, 'event-after-fallback-throw');
    coordinator.dispose();
  });

  test('throwing completion drains queued motions in FIFO order', () {
    final completed = <String>[];
    final coordinator = ScoringMotionCoordinator(
      onComplete: (event) {
        if (event.id == 'event-0') throw StateError('first failed');
        completed.add(event.id);
      },
    );
    for (var i = 0; i < 3; i++) {
      coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('$i'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      );
    }
    expect(
      () => coordinator.advance(const Duration(milliseconds: 760)),
      throwsA(isA<StateError>()),
    );
    expect(coordinator.active?.event.id, 'event-1');
    coordinator.advance(const Duration(milliseconds: 760));
    expect(coordinator.active?.event.id, 'event-2');
    coordinator.advance(const Duration(milliseconds: 760));
    expect(completed, ['event-1', 'event-2']);
    coordinator.dispose();
  });

  test('throwing fallback during active failure starts the next event', () {
    final coordinator = ScoringMotionCoordinator(
      onFallback: (event) {
        if (event.id == 'event-fail-0') {
          throw StateError('asset failed');
        }
      },
    );
    for (var i = 0; i < 2; i++) {
      coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('fail-$i'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      );
    }
    expect(() => coordinator.fail('event-fail-0'), throwsA(isA<StateError>()));
    expect(coordinator.active?.event.id, 'event-fail-1');
    coordinator.dispose();
  });

  test('cancels active and queued events and dispose clears safely', () {
    final completed = <String>[];
    final coordinator = ScoringMotionCoordinator(
      onComplete: (event) => completed.add(event.id),
    );
    for (var i = 0; i < 3; i++) {
      coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('$i'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      );
    }
    expect(coordinator.cancelByLocationId('location-0'), isTrue);
    expect(coordinator.cancelByEventId('event-2'), isTrue);
    expect(coordinator.pendingCount, 1);
    coordinator.dispose();
    coordinator.advance(const Duration(seconds: 5));
    expect(completed, isEmpty);
    expect(coordinator.pendingCount, 0);
  });

  test(
    'reduced mode performs a bounded color reveal while disabled is immediate',
    () {
      final reducedCompleted = <String>[];
      final reduced = ScoringMotionCoordinator(
        mode: ScoringMotionMode.reduced,
        onComplete: (event) => reducedCompleted.add(event.id),
      );
      reduced.submit(
        ScoringMotionEvent(
          receipt: receipt('reduced'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      );
      expect(reduced.active, isNotNull);
      expect(reduced.active!.isColorReveal, isTrue);
      expect(reduced.active!.travelEnabled, isFalse);
      expect(reduced.active!.trailEnabled, isFalse);
      expect(reduced.active!.colorRevealProgress, 0);
      reduced.advance(const Duration(milliseconds: 119));
      expect(reduced.active, isNotNull);
      expect(reduced.active!.colorRevealProgress, closeTo(.99, .002));
      expect(reducedCompleted, isEmpty);
      reduced.advance(const Duration(milliseconds: 1));
      expect(reducedCompleted, ['event-reduced']);
      reduced.dispose();

      final disabledCompleted = <String>[];
      final disabled = ScoringMotionCoordinator(
        mode: ScoringMotionMode.disabled,
        onComplete: (event) => disabledCompleted.add(event.id),
      );
      disabled.submit(
        ScoringMotionEvent(
          receipt: receipt('disabled'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      );
      expect(disabledCompleted, ['event-disabled']);
      expect(disabled.active, isNull);
      disabled.dispose();
    },
  );

  test('disabled mode completes immediately when its asset is unavailable', () {
    final completed = <String>[];
    final fallbacks = <String>[];
    final coordinator = ScoringMotionCoordinator(
      mode: ScoringMotionMode.disabled,
      onComplete: (event) => completed.add(event.id),
      onFallback: (event) => fallbacks.add(event.id),
    );

    coordinator.submit(
      ScoringMotionEvent(
        receipt: receipt('disabled-missing-asset'),
        sourceButton: const Offset(20, 20),
        courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
        safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        assetAvailable: false,
      ),
    );

    expect(completed, ['event-disabled-missing-asset']);
    expect(fallbacks, isEmpty);
    expect(coordinator.active, isNull);
    coordinator.dispose();
  });

  test('reduced mode reveals for 120ms when its asset is unavailable', () {
    final completed = <String>[];
    final fallbacks = <String>[];
    final coordinator = ScoringMotionCoordinator(
      mode: ScoringMotionMode.reduced,
      onComplete: (event) => completed.add(event.id),
      onFallback: (event) => fallbacks.add(event.id),
    );

    coordinator.submit(
      ScoringMotionEvent(
        receipt: receipt('reduced-missing-asset'),
        sourceButton: const Offset(20, 20),
        courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
        safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        assetAvailable: false,
      ),
    );

    expect(coordinator.active, isNotNull);
    expect(coordinator.active!.isColorReveal, isTrue);
    coordinator.advance(const Duration(milliseconds: 119));
    expect(completed, isEmpty);
    coordinator.advance(const Duration(milliseconds: 1));
    expect(completed, ['event-reduced-missing-asset']);
    expect(fallbacks, isEmpty);
    coordinator.dispose();
  });

  testWidgets(
    'reduced overlay paints a destination marker through the 120ms reveal',
    (tester) async {
      final completed = <String>[];
      final coordinator = ScoringMotionCoordinator(
        mode: ScoringMotionMode.reduced,
        onComplete: (event) => completed.add(event.id),
      );
      final event = ScoringMotionEvent(
        receipt: receipt('reduced-marker', x: .25, y: .75),
        sourceButton: const Offset(20, 20),
        courtBounds: const Rect.fromLTWH(100, 200, 400, 200),
        safeWorkspace: const Rect.fromLTWH(0, 0, 600, 500),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(),
          home: ScoringMotionOverlay(coordinator: coordinator),
        ),
      );
      coordinator.submit(event);
      await tester.pump();

      List<RecordedInvocation> circles() {
        final customPaint = tester.widget<CustomPaint>(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is ScoringMotionPainter,
          ),
        );
        final canvas = TestRecordingCanvas();
        (customPaint.painter! as ScoringMotionPainter).paint(
          canvas,
          const Size(600, 500),
        );
        return canvas.invocations
            .where((call) => call.invocation.memberName == #drawCircle)
            .toList();
      }

      final expectedColor = teamColorForScheme(
        TeamSide.blue,
        buildHoopitoTheme().colorScheme,
      );
      expect(find.byType(LottieBuilder), findsNothing);
      final initial = circles();
      expect(initial, hasLength(1));
      expect(
        initial.single.invocation.positionalArguments[0],
        event.destination,
      );
      final initialColor =
          (initial.single.invocation.positionalArguments[2] as Paint).color;
      expect(initialColor.a, 0);
      expect(initialColor.r, closeTo(expectedColor.r, .001));
      expect(initialColor.g, closeTo(expectedColor.g, .001));
      expect(initialColor.b, closeTo(expectedColor.b, .001));

      coordinator.advance(const Duration(milliseconds: 60));
      await tester.pump();
      final midpoint = circles();
      expect(midpoint, hasLength(1));
      expect(
        midpoint.single.invocation.positionalArguments[0],
        event.destination,
      );
      expect(
        (midpoint.single.invocation.positionalArguments[2] as Paint).color.a,
        closeTo(.5, .001),
      );
      expect(
        (midpoint.single.invocation.positionalArguments[2] as Paint).color.r,
        closeTo(expectedColor.r, .001),
      );
      expect(find.byType(LottieBuilder), findsNothing);

      coordinator.advance(const Duration(milliseconds: 60));
      await tester.pump();
      expect(completed, ['event-reduced-marker']);
      expect(coordinator.active, isNull);
      expect(circles(), isEmpty);
      expect(find.byType(LottieBuilder), findsNothing);
      coordinator.dispose();
    },
  );

  test('queued location cancellation removes its event timing entry', () {
    final coordinator = ScoringMotionCoordinator();
    for (var i = 0; i < 4; i++) {
      coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('$i'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      );
    }
    expect(coordinator.cancelByLocationId('location-2'), isTrue);
    coordinator.advance(const Duration(milliseconds: 760));
    expect(coordinator.active!.event.id, 'event-1');
    coordinator.advance(const Duration(milliseconds: 440));
    expect(coordinator.active!.event.id, 'event-3');
    expect(
      coordinator.active!.timing.flight,
      const Duration(milliseconds: 320),
    );
    coordinator.dispose();
  });

  test('runtime asset failure reveals and advances the queued motion', () {
    final completed = <String>[];
    final fallback = <String>[];
    final coordinator = ScoringMotionCoordinator(
      onComplete: (event) => completed.add(event.id),
      onFallback: (event) => fallback.add(event.id),
    );
    for (var i = 0; i < 2; i++) {
      coordinator.submit(
        ScoringMotionEvent(
          receipt: receipt('runtime-$i'),
          sourceButton: const Offset(20, 20),
          courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
          safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
        ),
      );
    }
    expect(coordinator.fail('event-runtime-0'), isTrue);
    expect(fallback, ['event-runtime-0']);
    expect(completed, ['event-runtime-0']);
    expect(coordinator.active!.event.id, 'event-runtime-1');
    coordinator.dispose();
  });

  testWidgets('overlay requests team-colored ball and splash assets by phase', (
    tester,
  ) async {
    final assets = <String>[];
    final colors = <Color>[];
    final coordinator = ScoringMotionCoordinator();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: ScoringMotionOverlay(
          coordinator: coordinator,
          assetBuilder: (context, active, color) {
            assets.add(active.assetName);
            colors.add(color);
            return ColoredBox(color: color);
          },
        ),
      ),
    );
    coordinator.submit(
      ScoringMotionEvent(
        receipt: receipt('assets'),
        sourceButton: const Offset(20, 20),
        courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
        safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
      ),
    );
    await tester.pump();
    expect(assets.last, 'assets/animations/paint_ball.json');
    expect(
      colors.last,
      teamColorForScheme(TeamSide.blue, buildHoopitoTheme().colorScheme),
    );
    coordinator.advance(const Duration(milliseconds: 480));
    await tester.pump();
    expect(assets.last, 'assets/animations/paint_splash.json');
    expect(
      colors.last,
      teamColorForScheme(TeamSide.blue, buildHoopitoTheme().colorScheme),
    );
    coordinator.dispose();
  });

  testWidgets(
    'stateful Lottie asset follows standard and accelerated impact durations',
    (tester) async {
      for (final accelerated in [false, true]) {
        final coordinator = ScoringMotionCoordinator();
        await tester.pumpWidget(
          MaterialApp(home: ScoringMotionOverlay(coordinator: coordinator)),
        );
        coordinator.submit(
          ScoringMotionEvent(
            receipt: receipt('duration-$accelerated-0'),
            sourceButton: const Offset(20, 20),
            courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
            safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
          ),
        );
        if (accelerated) {
          for (var i = 1; i < 5; i++) {
            coordinator.submit(
              ScoringMotionEvent(
                receipt: receipt('duration-$accelerated-$i'),
                sourceButton: const Offset(20, 20),
                courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
                safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
              ),
            );
          }
        }
        await tester.pump();
        if (accelerated) {
          coordinator.advance(const Duration(milliseconds: 760));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        final flightState = tester.state<ScoringMotionLottieAssetState>(
          find.byType(ScoringMotionLottieAsset),
        );
        final expectedFlight = accelerated
            ? const Duration(milliseconds: 320)
            : const Duration(milliseconds: 480);
        expect(flightState.animationDuration, expectedFlight);
        coordinator.advance(expectedFlight);
        await tester.pump();
        await tester.pumpAndSettle();
        final impactState = tester.state<ScoringMotionLottieAssetState>(
          find.byType(ScoringMotionLottieAsset),
        );
        expect(
          impactState.animationDuration,
          accelerated
              ? const Duration(milliseconds: 120)
              : const Duration(milliseconds: 180),
        );
        coordinator.dispose();
      }
    },
  );

  testWidgets('disposing a Lottie asset ignores late composition callbacks', (
    tester,
  ) async {
    final coordinator = ScoringMotionCoordinator();
    await tester.pumpWidget(
      MaterialApp(home: ScoringMotionOverlay(coordinator: coordinator)),
    );
    coordinator.submit(
      ScoringMotionEvent(
        receipt: receipt('late-dispose'),
        sourceButton: const Offset(20, 20),
        courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
        safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    coordinator.dispose();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('default overlay uses offline Lottie assets', (tester) async {
    final coordinator = ScoringMotionCoordinator();
    await tester.pumpWidget(
      MaterialApp(home: ScoringMotionOverlay(coordinator: coordinator)),
    );
    coordinator.submit(
      ScoringMotionEvent(
        receipt: receipt('default-assets'),
        sourceButton: const Offset(20, 20),
        courtBounds: const Rect.fromLTWH(0, 0, 400, 400),
        safeWorkspace: const Rect.fromLTWH(0, 0, 400, 400),
      ),
    );
    await tester.pump();
    expect(find.byType(LottieBuilder), findsOneWidget);
    coordinator.dispose();
  });

  test(
    'receipt point maps to court overlay and asset failure reveals immediately',
    () {
      final event = ScoringMotionEvent(
        receipt: receipt('fallback', x: .25, y: .75),
        sourceButtonCoordinate: const Offset(20, 30),
        courtBounds: const Rect.fromLTWH(100, 200, 400, 200),
        safeWorkspace: const Rect.fromLTWH(0, 0, 600, 500),
        assetAvailable: false,
      );
      expect(event.sourceButton, const Offset(20, 30));
      expect(event.destination, const Offset(200, 350));
      final completed = <String>[];
      final fallbacks = <String>[];
      final coordinator = ScoringMotionCoordinator(
        onComplete: (item) => completed.add(item.id),
        onFallback: (item) => fallbacks.add(item.id),
      );
      coordinator.submit(event);
      expect(fallbacks, ['event-fallback']);
      expect(completed, ['event-fallback']);
      coordinator.dispose();
    },
  );

  testWidgets('overlay is a repaint-boundary custom painter primitive', (
    tester,
  ) async {
    final coordinator = ScoringMotionCoordinator();
    await tester.pumpWidget(
      MaterialApp(home: ScoringMotionOverlay(coordinator: coordinator)),
    );
    expect(find.byType(RepaintBoundary), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is ScoringMotionPainter,
      ),
      findsOneWidget,
    );
    coordinator.dispose();
  });
}
