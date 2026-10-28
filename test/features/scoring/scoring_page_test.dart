import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/motion/scoring_motion.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';
import 'package:hoopito/features/scoring/widgets/score_side_panel.dart';

import '../../test_helpers/test_database.dart';

class _GatedSupplementController extends ScoringController {
  _GatedSupplementController(this.result)
    : super(matchId: 'gated-supplement-controller');

  final Future<ShotLocationCommitReceipt?> result;

  @override
  Future<ShotLocationCommitReceipt?> attachSupplementLocationWithReceipt(
    CourtPoint point, {
    DateTime? requestedAtUtc,
    String? eventId,
  }) => result;
}

class _BusyPauseController extends ScoringController {
  _BusyPauseController() : super(matchId: 'busy-pause-controller');

  @override
  Future<bool> pauseCommitted() async => false;
}

class _FailingPauseController extends ScoringController {
  _FailingPauseController() : super(matchId: 'failing-pause-controller');

  var retryWithReceiptCalls = 0;

  late final MatchCommandFailure failure = MatchCommandFailure(
    command: PauseMatchCommand(
      matchId: state.matchId,
      occurredAt: DateTime.utc(2026, 8, 27, 12),
    ),
    message: 'retryable pause failure',
    canRetry: true,
  );

  @override
  Future<bool> pauseCommitted() => Future<bool>.error(failure);

  @override
  Future<ScoringCommandRetryResult> retryCommandWithReceipt(
    MatchCommandFailure failure,
  ) async {
    retryWithReceiptCalls++;
    return const ScoringCommandRetryResult(accepted: true);
  }
}

class _NonRetryableResumeController extends ScoringController {
  _NonRetryableResumeController()
    : super(matchId: 'non-retryable-resume-controller');

  late final MatchCommandFailure failure = MatchCommandFailure(
    command: ResumeMatchCommand(
      matchId: state.matchId,
      occurredAt: DateTime.utc(2026, 8, 27, 12),
    ),
    message: 'resume validation failed',
    canRetry: false,
  );

  @override
  Future<bool> resumeCommitted() => Future<bool>.error(failure);
}

class _FailingScoreController extends ScoringController {
  _FailingScoreController(String matchId) : super(matchId: matchId);

  var retryWithReceiptCalls = 0;

  late final MatchCommandFailure failure = MatchCommandFailure(
    command: RecordMatchEventCommand(
      matchId: state.matchId,
      side: TeamSide.red,
      points: 1,
      occurredAt: DateTime.utc(2026, 8, 25, 12),
    ),
    message: 'retryable score failure',
    canRetry: true,
  );

  @override
  Future<bool> recordScoreCommitted({
    required TeamSide side,
    required int points,
    DateTime? occurredAt,
  }) => Future<bool>.error(failure);

  @override
  Future<ScoringCommandRetryResult> retryCommandWithReceipt(
    MatchCommandFailure failure,
  ) async {
    retryWithReceiptCalls++;
    return const ScoringCommandRetryResult(accepted: true);
  }
}

class _RetryTrackingController extends ScoringController {
  _RetryTrackingController(String matchId) : super(matchId: matchId);

  var retryWithReceiptCalls = 0;

  @override
  Future<ScoringCommandRetryResult> retryCommandWithReceipt(
    MatchCommandFailure failure,
  ) async {
    retryWithReceiptCalls++;
    return const ScoringCommandRetryResult(accepted: true);
  }
}

class _GatedRetryController extends _FailingScoreController {
  _GatedRetryController(super.matchId, this.retryResult);

  final Future<ScoringCommandRetryResult> retryResult;

  @override
  Future<ScoringCommandRetryResult> retryCommandWithReceipt(
    MatchCommandFailure failure,
  ) async {
    retryWithReceiptCalls++;
    return retryResult;
  }
}

void main() {
  testWidgets('miss rail records immediately and exposes a location window', (
    tester,
  ) async {
    final anchor = DateTime.utc(2026, 9, 14, 9);
    await withTestDatabase((database) async {
      final service = MatchCommandService(database, now: () => anchor);
      final start = await service.start(
        _startPageCommand('miss-rail-location-window', createdAt: anchor),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
        nowUtc: () => anchor,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(controller: controller, clockNowUtc: () => anchor),
        ),
      );

      await tester.tap(find.byKey(const Key('blue-miss')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();

      expect(controller.state.events.single.outcome, ShotOutcome.missed);
      expect(controller.locationSupplementWindow?.points, 0);
      expect(
        find.byKey(const Key('blue-miss-location-affordance')),
        findsOneWidget,
      );
      expect(find.textContaining('补充蓝方未命中落点'), findsOneWidget);

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(controller.locationSupplementWindow, isNull);
      expect(controller.state.shotLocations.single.isMiss, isTrue);
    });
  });

  testWidgets('More independently filters blue and red miss locations', (
    tester,
  ) async {
    final anchor = DateTime.utc(2026, 9, 14, 10);
    await withTestDatabase((database) async {
      final service = MatchCommandService(database, now: () => anchor);
      final start = await service.start(
        _startPageCommand('miss-marker-visibility', createdAt: anchor),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
        nowUtc: () => anchor,
      );
      await controller.recordFieldGoalCommitted(
        side: TeamSide.blue,
        outcome: ShotOutcome.missed,
        location: CourtPoint(x: 0.2, y: 0.4),
      );
      await controller.recordFieldGoalCommitted(
        side: TeamSide.red,
        outcome: ShotOutcome.missed,
        location: CourtPoint(x: 0.8, y: 0.4),
      );
      await controller.recordFieldGoalCommitted(
        side: TeamSide.blue,
        outcome: ShotOutcome.made,
        points: 2,
        location: CourtPoint(x: 0.5, y: 0.7),
      );
      final blueMiss = controller.state.shotLocations.singleWhere(
        (location) => location.side == TeamSide.blue && location.isMiss,
      );
      final redMiss = controller.state.shotLocations.singleWhere(
        (location) => location.side == TeamSide.red && location.isMiss,
      );
      final made = controller.state.shotLocations.singleWhere(
        (location) => !location.isMiss,
      );
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );

      await tester.tap(find.byKey(const Key('scoring-more')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(
              find.byKey(const Key('more-show-blue-misses-switch')),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('more-show-blue-misses-switch')));
      await tester.pump();

      expect(find.byKey(const Key('scoring-more-sheet')), findsOneWidget);
      var court = tester.widget<CourtView>(find.byType(CourtView));
      expect(court.hiddenShotLocationIds, contains(blueMiss.id));
      expect(court.hiddenShotLocationIds, isNot(contains(redMiss.id)));
      expect(court.hiddenShotLocationIds, isNot(contains(made.id)));

      await tester.tap(find.byKey(const Key('more-show-red-misses-switch')));
      await tester.pump();
      court = tester.widget<CourtView>(find.byType(CourtView));
      expect(
        court.hiddenShotLocationIds,
        containsAll([blueMiss.id, redMiss.id]),
      );
      expect(court.hiddenShotLocationIds, isNot(contains(made.id)));
      expect(await database.select(database.matchEvents).get(), hasLength(3));
      expect(await database.select(database.shotLocations).get(), hasLength(3));
    });
  });

  testWidgets('top foul menu records either side and remains undoable', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'top-foul-selector');
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );

    expect(
      tester.getSize(find.byKey(const Key('scoring-foul'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(const Key('scoring-foul')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-foul-blue')), findsOneWidget);
    expect(find.byKey(const Key('scoring-foul-red')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('scoring-foul-blue'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(const Key('scoring-foul-blue')));
    await tester.pump();
    await tester.pump();
    expect(controller.state.blueFouls, 1);

    await tester.tap(find.byKey(const Key('scoring-undo')));
    await tester.pump();
    expect(controller.state.blueFouls, 0);
  });

  testWidgets(
    'court-first receipt queues one hero and reveals durable marker after impact',
    (tester) async {
      final controller = ScoringController(matchId: 'task4-hero-success');
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await tester.tap(find.byKey(const Key('blue-score-2')));
      await tester.pump();

      final overlay = tester.widget<ScoringMotionOverlay>(
        find.byType(ScoringMotionOverlay),
      );
      expect(overlay.coordinator.pendingCount, 1);
      expect(controller.state.shotLocations, hasLength(1));
      var court = tester.widget<CourtView>(find.byType(CourtView));
      expect(court.hiddenShotLocationIds, hasLength(1));
      expect(court.transientMarkers, hasLength(1));
      await tester.pump(const Duration(milliseconds: 470));
      expect(overlay.coordinator.active, isNotNull);
      expect(
        tester.widget<CourtView>(find.byType(CourtView)).hiddenShotLocationIds,
        hasLength(1),
      );
      await tester.pump(const Duration(milliseconds: 20));
      court = tester.widget<CourtView>(find.byType(CourtView));
      expect(court.hiddenShotLocationIds, isEmpty);
      expect(court.transientMarkers, isEmpty);
      await tester.pump(const Duration(milliseconds: 800));
      expect(overlay.coordinator.active, isNull);
      expect(overlay.coordinator.pendingCount, 0);
    },
  );

  testWidgets('undo cancels the active location motion with a timed eraser', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'task4-eraser-active');
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.tap(find.byKey(const Key('blue-score-2')));
    await tester.pump();
    expect(
      tester
          .widget<ScoringMotionOverlay>(find.byType(ScoringMotionOverlay))
          .coordinator
          .active,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('scoring-undo')));
    await tester.pump();
    var court = tester.widget<CourtView>(find.byType(CourtView));
    expect(court.eraserMarkers, hasLength(1));
    expect(
      tester
          .widget<ScoringMotionOverlay>(find.byType(ScoringMotionOverlay))
          .coordinator
          .active,
      isNull,
    );
    final startProgress = court.eraserMarkers.single.progress;
    await tester.pump(const Duration(milliseconds: 100));
    court = tester.widget<CourtView>(find.byType(CourtView));
    expect(court.eraserMarkers.single.progress, greaterThan(startProgress));
    expect(court.eraserMarkers.single.progress, closeTo(0.5, 0.15));
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      tester.widget<CourtView>(find.byType(CourtView)).eraserMarkers,
      isEmpty,
    );
  });

  testWidgets('reduced-motion undo skips the transient eraser projection', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'task4-eraser-reduced');
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          controller: controller,
          motionPreference: MotionPreference.reduced,
        ),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.tap(find.byKey(const Key('blue-score-2')));
    await tester.pump();
    expect(controller.state.shotLocations, hasLength(1));

    await tester.tap(find.byKey(const Key('scoring-undo')));
    await tester.pump();

    final court = tester.widget<CourtView>(find.byType(CourtView));
    expect(controller.state.shotLocations, isEmpty);
    expect(court.transientMarkers, isEmpty);
    expect(court.eraserMarkers, isEmpty);
  });

  testWidgets('system-disabled undo skips the transient eraser projection', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'task4-eraser-disabled');
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ScoringPage(controller: controller),
        ),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.tap(find.byKey(const Key('red-score-3')));
    await tester.pump();
    expect(controller.state.shotLocations, hasLength(1));

    await tester.tap(find.byKey(const Key('scoring-undo')));
    await tester.pump();

    final court = tester.widget<CourtView>(find.byType(CourtView));
    expect(controller.state.shotLocations, isEmpty);
    expect(court.transientMarkers, isEmpty);
    expect(court.eraserMarkers, isEmpty);
  });

  testWidgets('system-disabled scoring reveals receipt without a flight', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'task4-hero-disabled');
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ScoringPage(controller: controller),
        ),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.tap(find.byKey(const Key('red-score-3')));
    await tester.pump();
    final overlay = tester.widget<ScoringMotionOverlay>(
      find.byType(ScoringMotionOverlay),
    );
    expect(overlay.coordinator.active, isNull);
    expect(overlay.coordinator.pendingCount, 0);
    expect(controller.state.shotLocations, hasLength(1));
  });

  testWidgets(
    'scoring reacts to shared motion preference changes after mount',
    (tester) async {
      final database = createTestDatabase();
      final feedback = ScoringFeedbackService(
        ScoringFeedbackPreferencesRepository(database),
      );
      final controller = ScoringController(matchId: 'reactive-motion');
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            motionPreferenceListenable: feedback.motionPreferenceListenable,
          ),
        ),
      );

      ScoringMotionOverlay overlay() => tester.widget<ScoringMotionOverlay>(
        find.byType(ScoringMotionOverlay),
      );
      expect(overlay().coordinator.mode, ScoringMotionMode.standard);

      await feedback.setMotionPreference(MotionPreference.reduced);
      await tester.pump();
      expect(overlay().coordinator.mode, ScoringMotionMode.reduced);

      await feedback.setMotionPreference(MotionPreference.standard);
      await tester.pump();
      expect(overlay().coordinator.mode, ScoringMotionMode.standard);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: ScoringPage(
              controller: controller,
              motionPreferenceListenable: feedback.motionPreferenceListenable,
            ),
          ),
        ),
      );
      expect(overlay().coordinator.mode, ScoringMotionMode.disabled);
      await feedback.setMotionPreference(MotionPreference.reduced);
      await tester.pump();
      expect(overlay().coordinator.mode, ScoringMotionMode.disabled);
    },
  );

  testWidgets('scoring detaches a replaced motion preference listenable', (
    tester,
  ) async {
    final previous = ValueNotifier(MotionPreference.standard);
    final replacement = ValueNotifier(MotionPreference.standard);
    addTearDown(previous.dispose);
    addTearDown(replacement.dispose);

    Widget page(ValueListenable<MotionPreference> listenable) {
      return MaterialApp(
        home: ScoringPage(
          controller: ScoringController(matchId: 'replace-motion'),
          motionPreferenceListenable: listenable,
        ),
      );
    }

    await tester.pumpWidget(page(previous));
    await tester.pumpWidget(page(replacement));
    previous.value = MotionPreference.reduced;
    await tester.pump();
    expect(
      tester
          .widget<ScoringMotionOverlay>(find.byType(ScoringMotionOverlay))
          .coordinator
          .mode,
      ScoringMotionMode.standard,
    );
    replacement.value = MotionPreference.reduced;
    await tester.pump();
    expect(
      tester
          .widget<ScoringMotionOverlay>(find.byType(ScoringMotionOverlay))
          .coordinator
          .mode,
      ScoringMotionMode.reduced,
    );
  });

  testWidgets(
    'reactive scoring seam loads persisted preference on first mount',
    (tester) async {
      final database = createTestDatabase();
      await database
          .into(database.appSettings)
          .insert(
            AppSetting(
              key: scoringFeedbackPreferencesKey,
              valueJson:
                  '{"version":1,"haptic":true,"sound":false,"motion":"reduced"}',
              updatedAt: DateTime.utc(2026, 8, 26),
            ),
          );
      final feedback = ScoringFeedbackService(
        ScoringFeedbackPreferencesRepository(database),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: ScoringController(matchId: 'persisted-motion'),
            motionPreferenceListenable: feedback.motionPreferenceListenable,
            motionPreferenceLoader: () async => (await feedback.load()).motion,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ScoringMotionOverlay>(find.byType(ScoringMotionOverlay))
            .coordinator
            .mode,
        ScoringMotionMode.reduced,
      );
    },
  );

  testWidgets(
    'score press compresses for 90ms but reduced motion stays static',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ScoringPage(matchId: 'press-feedback')),
      );
      final button = find.byKey(const Key('red-score-1'));
      final scaleFinder = find.ancestor(
        of: button,
        matching: find.byType(AnimatedScale),
      );
      expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));
      expect(tester.widget<AnimatedScale>(scaleFinder).scale, 1);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(scaleFinder).scale,
        closeTo(.96, .01),
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<AnimatedScale>(scaleFinder).scale, 1);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: ScoringPage(matchId: 'press-feedback-disabled'),
          ),
        ),
      );
      final disabledScaleFinder = find.ancestor(
        of: find.byKey(const Key('red-score-1')),
        matching: find.byType(AnimatedScale),
      );
      final disabledGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('red-score-1'))),
      );
      await tester.pump();
      expect(tester.widget<AnimatedScale>(disabledScaleFinder).scale, 1);
      await disabledGesture.up();
    },
  );

  testWidgets(
    'foul stamp uses a one-shot entrance and reduced mode is static',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ScoringPage(matchId: 'foul-stamp-motion')),
      );
      await _tapFoul(tester, TeamSide.red);
      await tester.pump();
      expect(find.byKey(const Key('scoring-foul-stamp')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('scoring-foul-stamp')),
          matching: find.byType(TweenAnimationBuilder<double>),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 120));
      await _tapFoul(tester, TeamSide.red);
      await tester.pump();
      expect(find.byKey(const Key('scoring-foul-stamp')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.byKey(const Key('scoring-foul-stamp')), findsNothing);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: ScoringPage(matchId: 'foul-stamp-disabled'),
          ),
        ),
      );
      await _tapFoul(tester, TeamSide.red);
      await tester.pump();
      expect(find.byKey(const Key('scoring-foul-stamp')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('scoring-foul-stamp')),
          matching: find.byType(TweenAnimationBuilder<double>),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('top undo removes the latest foul from the scoring surface', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'page-foul-undo');
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );

    await _tapFoul(tester, TeamSide.red);
    await tester.pump();
    expect(controller.state.redFouls, 1);

    await tester.tap(find.byKey(const Key('scoring-undo')));
    await tester.pump();
    expect(controller.state.redFouls, 0);
    expect(
      controller.state.events
          .singleWhere((event) => event.type == EventKind.foul)
          .isDeleted,
      isTrue,
    );
  });

  testWidgets('score switch animates only the numeric value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'score-switch-motion')),
    );
    expect(find.byKey(const ValueKey<int>(0)), findsAtLeastNWidgets(2));
    expect(find.text('0 红方'), findsOneWidget);
    await tester.tap(find.byKey(const Key('red-score-1')));
    await tester.pump();
    expect(find.byKey(const ValueKey<int>(1)), findsOneWidget);
    expect(find.text('1 红方'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byKey(const ValueKey<int>(1)), findsOneWidget);
  });

  testWidgets('a supplement receipt from a replaced controller is ignored', (
    tester,
  ) async {
    final result = Completer<ShotLocationCommitReceipt?>();
    final oldController = _GatedSupplementController(result.future);
    await oldController.recordScoreCommitted(side: TeamSide.red, points: 2);
    var committed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          controller: oldController,
          onActionCommitted: () => committed++,
        ),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.pump();
    tester.binding.handleMetricsChanged();
    await tester.pump();
    expect(
      tester
          .widget<ScoringMotionOverlay>(find.byType(ScoringMotionOverlay))
          .coordinator
          .pendingCount,
      0,
    );

    final replacement = ScoringController(matchId: 'replacement-controller');
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: replacement)),
    );
    result.complete(
      ShotLocationCommitReceipt(
        eventId: 'old-event',
        shotLocationId: 'old-shot',
        side: TeamSide.red,
        points: 2,
        point: CourtPoint(x: 0.4, y: 0.4),
        source: ShotLocationCommitSource.supplement,
      ),
    );
    await tester.pump();

    expect(committed, 0);
    expect(
      tester
          .widget<ScoringMotionOverlay>(find.byType(ScoringMotionOverlay))
          .coordinator
          .pendingCount,
      0,
    );
    expect(
      tester.widget<CourtView>(find.byType(CourtView)).hiddenShotLocationIds,
      isEmpty,
    );
  });

  testWidgets('a stale SnackBar retry cannot target a replacement controller', (
    tester,
  ) async {
    final oldController = _FailingScoreController('same-match-id');
    final replacement = _RetryTrackingController('same-match-id');
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: oldController)),
    );
    await tester.tap(find.byKey(const Key('red-score-1')));
    await tester.pump();
    expect(find.byType(SnackBarAction), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: replacement)),
    );
    final retry = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    retry.onPressed();
    await tester.pump();

    expect(oldController.retryWithReceiptCalls, 0);
    expect(replacement.retryWithReceiptCalls, 0);
    expect(replacement.state.events, isEmpty);
  });

  testWidgets(
    'successful retry action is consumed while an in-flight duplicate is ignored',
    (tester) async {
      final retryResult = Completer<ScoringCommandRetryResult>();
      final controller = _GatedRetryController(
        'in-flight-retry',
        retryResult.future,
      );
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );
      await tester.tap(find.byKey(const Key('red-score-1')));
      await tester.pump();
      expect(find.byType(SnackBarAction), findsOneWidget);

      final retryAction = tester.widget<SnackBarAction>(
        find.byType(SnackBarAction),
      );
      retryAction.onPressed();
      retryAction.onPressed();
      expect(controller.retryWithReceiptCalls, 1);

      retryResult.complete(const ScoringCommandRetryResult(accepted: true));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();

      expect(controller.retryWithReceiptCalls, 1);
      expect(find.byType(SnackBarAction), findsNothing);
      retryAction.onPressed();
      await tester.pump();
      expect(controller.retryWithReceiptCalls, 1);
    },
  );

  testWidgets('failed retry keeps a retry action available', (tester) async {
    final retryResult = Completer<ScoringCommandRetryResult>();
    final retryFailure = MatchCommandFailure(
      command: RecordMatchEventCommand(
        matchId: 'failed-retry',
        side: TeamSide.red,
        points: 1,
        occurredAt: DateTime.utc(2026, 8, 25, 12),
      ),
      message: 'retry failed once',
      canRetry: true,
    );
    final controller = _GatedRetryController(
      'failed-retry',
      retryResult.future,
    );
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );
    await tester.tap(find.byKey(const Key('red-score-1')));
    await tester.pump();
    final firstRetry = tester.widget<SnackBarAction>(
      find.byType(SnackBarAction),
    );
    firstRetry.onPressed();
    retryResult.completeError(retryFailure);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(controller.retryWithReceiptCalls, 1);
    expect(find.byType(SnackBarAction), findsOneWidget);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(controller.retryWithReceiptCalls, 2);
    expect(find.byType(SnackBarAction), findsOneWidget);
  });

  testWidgets('unified scoring keeps secondary actions behind More', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'unified-layout')),
    );

    expect(find.byKey(const Key('scoring-undo')), findsOneWidget);
    expect(find.byKey(const Key('scoring-more')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('scoring-undo'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('scoring-more'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byKey(const Key('scoring-more')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scoring-more-sheet')), findsOneWidget);
    expect(find.byType(EditorialSheet), findsOneWidget);
    expect(find.byType(EditorialIndexRow), findsNWidgets(12));
    expect(find.byKey(const Key('more-quick-guide')), findsOneWidget);
    for (final section in const [
      'shooting',
      'free-throws',
      'match-state',
      'notes-records',
      'match',
    ]) {
      expect(find.byKey(Key('more-section-$section')), findsOneWidget);
    }
    expect(find.byKey(const Key('more-destructive-section')), findsNothing);
    expect(find.byKey(const Key('more-finish')), findsNothing);
    expect(find.byKey(const Key('more-show-blue-misses')), findsOneWidget);
    expect(find.byKey(const Key('more-show-red-misses')), findsOneWidget);
    expect(find.text('投篮显示'), findsOneWidget);
    expect(find.text('罚球'), findsOneWidget);
    expect(find.text('比赛状态'), findsOneWidget);
    expect(find.text('备注与自定义记录'), findsOneWidget);
    expect(find.text('比赛'), findsOneWidget);
  });

  testWidgets('visible finish control opens the explicit match control panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(731, 411));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          matchId: 'visible-match-controls',
          onFinishDecision: (_, _) async {},
        ),
      ),
    );

    final finish = find.byKey(const Key('scoring-finish'));
    expect(finish, findsOneWidget);
    expect(tester.getSize(finish).height, greaterThanOrEqualTo(48));
    await tester.tap(finish);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scoring-match-controls')), findsOneWidget);
    expect(find.text('结束或暂停比赛？'), findsOneWidget);
    expect(find.byKey(const Key('match-controls-return')), findsOneWidget);
    expect(find.byKey(const Key('match-controls-pause')), findsOneWidget);
    expect(find.byKey(const Key('match-controls-finish')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('match-controls-return'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('match-controls-return')))
          .style
          ?.minimumSize
          ?.resolve({})
          ?.height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('system back is blocked while pause is being committed', (
    tester,
  ) async {
    final pauseGate = Completer<void>();
    var leaveCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          matchId: 'pause-in-flight-back',
          onRequestLeave: () async => leaveCalls++,
          onPauseMatch: () => pauseGate.future,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-pause')));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(leaveCalls, 0);
    expect(find.byType(ScoringPage), findsOneWidget);

    pauseGate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
  });

  testWidgets('timer-free pause blocks back and preserves a gray court draft', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'local-pause-with-draft');
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.pump();
    expect(controller.courtFirstShotDraft, isNotNull);

    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-pause')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('paused-return-home'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('paused-return-home')))
          .style
          ?.minimumSize
          ?.resolve({})
          ?.height,
      greaterThanOrEqualTo(48),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    expect(controller.courtFirstShotDraft, isNotNull);

    await tester.tap(find.byKey(const Key('paused-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-paused-panel')), findsNothing);
    expect(controller.courtFirstShotDraft, isNotNull);
  });

  testWidgets('paused home warns before discarding a gray court draft', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'paused-home-draft');
    var homeCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          controller: controller,
          onReturnHomePaused: () async => homeCalls++,
        ),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-pause')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paused-return-home')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('paused-draft-discard')), findsOneWidget);
    expect(homeCalls, 0);
    await tester.tap(find.byKey(const Key('paused-draft-stay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    expect(controller.courtFirstShotDraft, isNotNull);

    await tester.tap(find.byKey(const Key('paused-return-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paused-draft-discard')));
    await tester.pumpAndSettle();
    expect(homeCalls, 1);
    expect(controller.courtFirstShotDraft, isNull);
  });

  testWidgets('route pause callbacks preserve drafts and resume durably', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final now = DateTime.utc(2026, 8, 27, 9);
      final service = MatchCommandService(database, now: () => now);
      final start = await service.start(
        _startPageCommand(
          'route-pause-draft',
          timerEnabled: true,
          clockMode: ClockMode.countUp,
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
      );
      var pauseCalls = 0;
      var resumeCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            clockNowUtc: () => now.add(const Duration(seconds: 1)),
            onPauseMatch: () async {
              pauseCalls++;
              final projection = await service.pause(
                PauseMatchCommand(
                  matchId: start.match.id,
                  occurredAt: now.add(const Duration(seconds: 1)),
                ),
              );
              controller.replaceCommittedProjection(projection);
            },
            onResumePausedMatch: () async {
              resumeCalls++;
              final projection = await service.resume(
                ResumeMatchCommand(
                  matchId: start.match.id,
                  occurredAt: now.add(const Duration(seconds: 2)),
                ),
              );
              controller.replaceCommittedProjection(projection);
            },
          ),
        ),
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('scoring-finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('match-controls-pause')));
      await tester.pumpAndSettle();

      expect(pauseCalls, 1);
      expect(controller.courtFirstShotDraft, isNotNull);
      expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
      await tester.tap(find.byKey(const Key('paused-continue')));
      await tester.pumpAndSettle();
      expect(resumeCalls, 1);
      expect(controller.courtFirstShotDraft, isNotNull);
      expect(find.byKey(const Key('scoring-paused-panel')), findsNothing);
    });
  });

  testWidgets('a persisted pause restores the blocking paused panel', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final now = DateTime.utc(2026, 8, 27, 10);
      final service = MatchCommandService(database, now: () => now);
      final start = await service.start(
        _startPageCommand(
          'restore-paused-panel',
          timerEnabled: true,
          clockMode: ClockMode.countUp,
        ),
      );
      final paused = await service.pause(
        PauseMatchCommand(
          matchId: start.match.id,
          occurredAt: now.add(const Duration(seconds: 1)),
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        paused,
        service,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            onResumePausedMatch: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
      expect(find.text('比赛已暂停'), findsOneWidget);
    });
  });

  testWidgets('pause failure does not enter the paused panel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          matchId: 'pause-failure-panel',
          onPauseMatch: () => Future<void>.error(StateError('offline')),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-pause')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scoring-paused-panel')), findsNothing);
    expect(find.text('操作失败，请重试。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('blue-score-1')));
    await tester.pump();
    expect(find.text('蓝方 1'), findsOneWidget);
  });

  testWidgets(
    'busy pause rejection reports feedback instead of failing silently',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: _BusyPauseController())),
      );
      await tester.tap(find.byKey(const Key('scoring-finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('match-controls-pause')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scoring-paused-panel')), findsNothing);
      expect(find.byKey(const Key('scoring-action-rejected')), findsOneWidget);
    },
  );

  testWidgets('pause retry keeps the court-first draft', (tester) async {
    final controller = _FailingPauseController();
    controller.beginOrMoveCourtFirstShot(CourtPoint(x: 0.42, y: 0.61));
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );

    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-pause')));
    await tester.pumpAndSettle();

    expect(controller.courtFirstShotDraft, isNotNull);
    expect(find.byType(SnackBarAction), findsOneWidget);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();

    expect(controller.retryWithReceiptCalls, 1);
    expect(controller.courtFirstShotDraft, isNotNull);
  });

  testWidgets('non-retryable resume failure stays inline without retry', (
    tester,
  ) async {
    final controller = _NonRetryableResumeController();
    expect(await controller.pauseCommitted(), isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          controller: controller,
          onReturnHomePaused: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paused-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    expect(find.byKey(const Key('paused-resume-failure')), findsOneWidget);
    expect(find.byKey(const Key('paused-retry')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resume failure keeps the blocking paused panel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          matchId: 'resume-failure-panel',
          onResumePausedMatch: () => Future<void>.error(StateError('offline')),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-pause')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paused-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    expect(find.text('操作失败，请重试。'), findsOneWidget);
  });

  testWidgets('double continue submits only one resume command', (
    tester,
  ) async {
    final resumeGate = Completer<void>();
    var resumeCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          matchId: 'resume-double-tap',
          onResumePausedMatch: () {
            resumeCalls++;
            return resumeGate.future;
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-pause')));
    await tester.pumpAndSettle();

    final continueButton = find.byKey(const Key('paused-continue'));
    await tester.tap(continueButton);
    await tester.pump();
    await tester.tap(continueButton, warnIfMissed: false);
    await tester.pump();
    expect(resumeCalls, 1);
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    resumeGate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-paused-panel')), findsNothing);
  });

  testWidgets('pause and resume each emit committed feedback once', (
    tester,
  ) async {
    var committed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          matchId: 'pause-feedback-once',
          onPauseMatch: () async {},
          onResumePausedMatch: () async {},
          onActionCommitted: () => committed++,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-pause')));
    await tester.pumpAndSettle();
    expect(committed, 1);
    await tester.tap(find.byKey(const Key('paused-continue')));
    await tester.pumpAndSettle();
    expect(committed, 2);
  });

  testWidgets('ordinary in-progress match can finish with its current score', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'manual-finish');
    await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
    var redScore = -1;
    var blueScore = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          controller: controller,
          onFinishDecision: (red, blue) async {
            redScore = red;
            blueScore = blue;
          },
        ),
      ),
    );

    expect(controller.state.decision, isNull);
    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-finish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-finish-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
    await tester.pumpAndSettle();
    expect(redScore, 2);
    expect(blueScore, 0);
  });

  for (final change in ['accessibility', 'preference', 'disabled']) {
    testWidgets('finish confirmation survives $change motion changes', (
      tester,
    ) async {
      final controller = ScoringController(matchId: 'finish-motion-$change');
      await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
      final preference = ValueNotifier(MotionPreference.standard);
      final media = ValueNotifier(const MediaQueryData());
      addTearDown(preference.dispose);
      addTearDown(media.dispose);
      var finishCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ValueListenableBuilder<MediaQueryData>(
            valueListenable: media,
            builder: (context, data, _) =>
                MediaQuery(data: data, child: child!),
          ),
          home: ScoringPage(
            controller: controller,
            motionPreferenceListenable: preference,
            onFinishWithCoverage: (red, blue, coverage) async {
              expect(red, 2);
              expect(blue, 0);
              expect(coverage, TrackingCoverage.scoresOnly);
              finishCalls++;
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('scoring-finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('match-controls-finish')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scoring-finish-confirm')), findsOneWidget);
      switch (change) {
        case 'accessibility':
          media.value = const MediaQueryData(accessibleNavigation: true);
        case 'preference':
          preference.value = MotionPreference.reduced;
        case 'disabled':
          media.value = const MediaQueryData(disableAnimations: true);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
      await tester.pumpAndSettle();
      expect(finishCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('canceling final confirmation keeps the gray court draft', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'finish-cancel-draft');
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          controller: controller,
          onFinishDecision: (_, _) async {},
        ),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-finish')));
    await tester.pumpAndSettle();

    expect(find.textContaining('灰色投篮点未确认'), findsOneWidget);
    await tester.tap(find.byKey(const Key('scoring-finish-cancel')));
    await tester.pumpAndSettle();
    expect(controller.courtFirstShotDraft, isNotNull);
  });

  testWidgets('failed finish keeps the gray court draft for retry', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'finish-failure-draft');
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          controller: controller,
          onFinishDecision: (_, _) => Future<void>.error(StateError('offline')),
        ),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
    await tester.pumpAndSettle();

    expect(controller.courtFirstShotDraft, isNotNull);
    expect(find.text('操作失败，请重试。'), findsOneWidget);
  });

  testWidgets('legacy win by two blocks finish until the lead reaches two', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final start = await service.start(
        _startPageCommand('finish-rule-gate', targetScore: 1, winByTwo: true),
      );
      final projection = await service.record(
        RecordMatchEventCommand(
          matchId: start.match.id,
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: DateTime.utc(2026, 8, 27, 9, 1),
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        projection,
        service,
      );
      expect(controller.state.decision?.canFinish, isFalse);
      final continued = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            onFinishDecision: (_, _) async {},
            onContinueDecision: () async {
              controller.replaceCommittedProjection(
                await service.continueMatch(
                  ContinueMatchCommand(
                    matchId: start.match.id,
                    occurredAt: DateTime.now().toUtc(),
                  ),
                ),
              );
              continued.complete();
            },
          ),
        ),
      );
      expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);
      expect(find.byKey(const Key('scoring-decision-finish')), findsNothing);
      expect(
        controller.state.decision?.reason,
        MatchDecisionReason.winByTwoRequired,
      );
      await tester.tap(find.byKey(const Key('scoring-decision-continue')));
      await tester.pump();
      await tester.runAsync(() => continued.future);
      await tester.pumpAndSettle();
      expect(controller.state.decision, isNull);
      expect(
        await controller.recordScoreCommitted(side: TeamSide.red, points: 1),
        isTrue,
      );
      controller.cancelLocateLastUnlocatedShot();
      await tester.pump();
      expect(controller.state.decision?.canFinish, isTrue);
      expect(find.byKey(const Key('scoring-decision-finish')), findsOneWidget);
    });
  });

  testWidgets('landscape scoring uses narrow paper editorial action rails', (
    tester,
  ) async {
    for (final size in const [Size(731, 411), Size(1095, 616)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(),
          home: const ScoringPage(matchId: 'editorial-action-rails'),
        ),
      );

      final editorial = const HoopitoEditorialTheme.light();
      final blueRail = tester.widget<Material>(
        find.byKey(const Key('blue-action-rail')),
      );
      final redRail = tester.widget<Material>(
        find.byKey(const Key('red-action-rail')),
      );
      expect(blueRail.color, editorial.canvas);
      expect(redRail.color, editorial.canvas);
      expect(blueRail.color, isNot(editorial.inverseSurface));
      expect(redRail.color, isNot(editorial.inverseSurface));

      final maximumRailWidth = size.width < 900 ? 128.0 : 188.0;
      expect(
        tester.getSize(find.byKey(const Key('blue-side-panel'))).width,
        lessThanOrEqualTo(maximumRailWidth),
      );
      expect(
        tester.getSize(find.byKey(const Key('red-side-panel'))).width,
        lessThanOrEqualTo(maximumRailWidth),
      );

      for (final side in const ['blue', 'red']) {
        final button = tester.widget<FilledButton>(
          find.byKey(Key('$side-score-1')),
        );
        expect(
          button.style?.shape?.resolve(const {}),
          isA<BeveledRectangleBorder>(),
        );
        expect(button.style?.elevation?.resolve(const {}), 0);
      }
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('court-first draft starts as a gray point with side prompt', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'unified-court-first');
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );

    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.pump();

    expect(controller.courtFirstShotDraft, isNotNull);
    expect(find.text('请选择蓝方或红方得分'), findsOneWidget);

    await tester.tap(find.byKey(const Key('blue-score-2')));
    await tester.pumpAndSettle();
    expect(controller.courtFirstShotDraft, isNull);
    expect(controller.state.score.blueScore, 2);
    expect(controller.state.shotLocations, hasLength(1));
  });

  testWidgets(
    'court-first draft keeps score buttons enabled for side selection',
    (tester) async {
      final controller = ScoringController(matchId: 'draft-score-selection');
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await tester.pump();

      final score = tester.widget<FilledButton>(
        find.byKey(const Key('blue-score-1')),
      );
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const Key('blue-score-1')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(score.onPressed, isNotNull);
      expect(semantics.properties.enabled, isTrue);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('blue-miss')))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('scoring-foul')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('legacy pending location disables score buttons and semantics', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'legacy-pending-score');
    controller.addScore(side: TeamSide.blue, points: 2);
    expect(controller.beginLocateLastUnlocatedShot(), isTrue);
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );

    final score = tester.widget<FilledButton>(
      find.byKey(const Key('blue-score-1')),
    );
    final semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const Key('blue-score-1')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(controller.state.pendingLocation, isNotNull);
    expect(controller.courtFirstShotDraft, isNull);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('blue-miss')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('scoring-foul')))
          .onPressed,
      isNull,
    );
    expect(score.onPressed, isNull);
    expect(semantics.properties.enabled, isFalse);
  });

  testWidgets('score-first exposes a ten-second location supplement on court', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'unified-score-first');
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );

    await tester.tap(find.byKey(const Key('red-score-3')));
    await tester.pump();

    expect(controller.locationSupplementWindow, isNotNull);
    expect(find.byKey(const Key('red-score-3-location')), findsOneWidget);
    expect(find.textContaining('补充红方 +3 落点'), findsOneWidget);

    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.pump();
    expect(controller.locationSupplementWindow, isNull);
    expect(controller.state.shotLocations, hasLength(1));
    final overlay = tester.widget<ScoringMotionOverlay>(
      find.byType(ScoringMotionOverlay),
    );
    expect(overlay.coordinator.pendingCount, 1);
    expect(
      tester.widget<CourtView>(find.byType(CourtView)).transientMarkers,
      hasLength(1),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester.widget<CourtView>(find.byType(CourtView)).hiddenShotLocationIds,
      isEmpty,
    );
  });

  testWidgets('idle scoring creates no periodic supplement timer', (
    tester,
  ) async {
    var periodicTimers = 0;

    await runZoned(
      () => tester.pumpWidget(
        const MaterialApp(home: ScoringPage(matchId: 'idle-no-wake')),
      ),
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          periodicTimers++;
          return parent.createPeriodicTimer(zone, duration, callback);
        },
      ),
    );

    expect(periodicTimers, 0);
  });

  testWidgets('active location affordance does not oscillate', (tester) async {
    final anchor = DateTime.utc(2026, 8, 27, 9);
    final controller = ScoringController(
      matchId: 'steady-location-affordance',
      nowUtc: () => anchor,
    )..addScore(side: TeamSide.red, points: 2);

    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(controller: controller, clockNowUtc: () => anchor),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final affordance = find.byKey(const Key('red-score-2-location-affordance'));
    final firstDecoration = tester
        .widget<AnimatedContainer>(affordance)
        .decoration;
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.widget<AnimatedContainer>(affordance).decoration,
      firstDecoration,
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byKey(const Key('red-score-2-location')), findsOneWidget);
  });

  testWidgets('supplement countdown expires at ten seconds', (tester) async {
    final anchor = DateTime.utc(2026, 8, 27, 9);
    var now = anchor;
    final controller = ScoringController(
      matchId: 'supplement-countdown-expiry',
      nowUtc: () => now,
    )..addScore(side: TeamSide.blue, points: 3);

    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(controller: controller, clockNowUtc: () => now),
      ),
    );
    expect(find.textContaining('10秒'), findsOneWidget);

    now = anchor.add(const Duration(seconds: 9, milliseconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('1秒'), findsOneWidget);
    expect(controller.locationSupplementWindow, isNotNull);

    now = anchor.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.locationSupplementWindow, isNull);
    expect(find.byKey(const Key('blue-score-3-location')), findsNothing);
  });

  for (final mode in <({bool disabled, bool reduced, Duration duration})>[
    (disabled: false, reduced: true, duration: Duration(milliseconds: 120)),
    (disabled: true, reduced: false, duration: Duration.zero),
  ]) {
    testWidgets('location reveal uses ${mode.duration.inMilliseconds}ms when '
        '${mode.disabled ? 'animations are disabled' : 'motion is reduced'}', (
      tester,
    ) async {
      final controller = ScoringController(
        matchId: 'location-reveal-${mode.duration.inMilliseconds}',
      )..addScore(side: TeamSide.red, points: 1);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: mode.disabled,
              accessibleNavigation: mode.reduced,
            ),
            child: ScoringPage(controller: controller),
          ),
        ),
      );

      final reveal = tester.widget<AnimatedContainer>(
        find.byKey(const Key('red-score-1-location-affordance')),
      );
      expect(reveal.duration, mode.duration);
    });
  }

  testWidgets(
    'score-first location window allows a foul and keeps its window',
    (tester) async {
      await withTestDatabase((database) async {
        final anchor = DateTime.utc(2026, 8, 23, 9);
        final service = MatchCommandService(database, now: () => anchor);
        final start = await service.start(
          _startPageCommand('score-first-foul-window'),
        );
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
          nowUtc: () => anchor,
        );
        await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
        final windowEventId = controller.locationSupplementWindow!.eventId;

        await tester.pumpWidget(
          MaterialApp(
            home: ScoringPage(
              controller: controller,
              clockNowUtc: () => anchor,
            ),
          ),
        );
        expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('scoring-foul')))
              .onPressed,
          isNotNull,
        );

        await _tapFoul(tester, TeamSide.red);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();

        expect(controller.state.redFouls, 1);
        expect(controller.locationSupplementWindow?.eventId, windowEventId);
        expect(await database.select(database.matchEvents).get(), hasLength(2));
      });
    },
  );

  testWidgets('score-first location window allows More actions', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final start = await service.start(
        _startPageCommand('score-first-more-window'),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
      );
      await controller.recordScoreCommitted(side: TeamSide.blue, points: 1);

      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );
      await tester.tap(find.byKey(const Key('scoring-more')));
      await tester.pumpAndSettle();

      final possession = tester.widget<EditorialIndexRow>(
        find.byKey(const Key('more-possession-blue')),
      );
      expect(possession.onTap, isNotNull);
      await tester.ensureVisible(find.byKey(const Key('more-possession-blue')));
      await tester.tap(find.byKey(const Key('more-possession-blue')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      expect(controller.state.currentPossession, TeamSide.blue);
      expect(controller.locationSupplementWindow, isNotNull);
      expect(await database.select(database.matchEvents).get(), hasLength(2));
    });
  });

  testWidgets(
    'next score closes the old supplement window and binds the latest score',
    (tester) async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = await service.start(
          _startPageCommand('score-first-next-score-window'),
        );
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
        );
        await tester.pumpWidget(
          MaterialApp(home: ScoringPage(controller: controller)),
        );
        await tester.tap(find.byKey(const Key('blue-score-1')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        final firstWindowEventId = controller.locationSupplementWindow!.eventId;

        await tester.tap(find.byKey(const Key('red-score-2')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();

        final latestEventId = controller.state.events.last.id;
        expect(controller.state.score.redScore, 2);
        expect(controller.locationSupplementWindow, isNotNull);
        expect(controller.locationSupplementWindow!.eventId, latestEventId);
        expect(
          controller.locationSupplementWindow!.eventId,
          isNot(firstWindowEventId),
        );
        expect(await database.select(database.matchEvents).get(), hasLength(2));
      });
    },
  );

  testWidgets('More text entries survive repeated open and cancel', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'unified-dialog-life');
    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('scoring-more')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('more-note')));
      await tester.tap(find.byKey(const Key('more-note')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.byKey(const Key('text-entry-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.drag(
        find.descendant(
          of: find.byKey(const Key('scoring-more-sheet')),
          matching: find.byType(SingleChildScrollView),
        ),
        const Offset(0, 500),
      );
      await tester.tap(find.byKey(const Key('more-close')));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('English More sheet exposes Notes and Custom Records', (
    tester,
  ) async {
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
        home: const ScoringPage(matchId: 'english-more-copy'),
      ),
    );
    await tester.tap(find.byKey(const Key('scoring-more')));
    await tester.pumpAndSettle();
    expect(
      find.text('NOTES AND CUSTOM RECORDS', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('more-note'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('more-custom'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('compact More sheet peeks the first action in the next section', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(731, 411));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'compact-more-peek')),
    );

    await tester.tap(find.byKey(const Key('scoring-more')));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('more-close'))).shortestSide,
      greaterThanOrEqualTo(48),
    );
    final scrollViewport = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('scoring-more-sheet')),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final nextAction = tester.getRect(
      find.byKey(const Key('more-blue-free-throw-made')),
    );
    final visibleHeight =
        nextAction.bottom.clamp(scrollViewport.top, scrollViewport.bottom) -
        nextAction.top.clamp(scrollViewport.top, scrollViewport.bottom);

    expect(nextAction.height, greaterThanOrEqualTo(48));
    expect(
      visibleHeight,
      greaterThanOrEqualTo(48),
      reason: 'The first action after the next section label must be visible.',
    );
  });

  testWidgets(
    'unified scoring remains operable across landscape and portrait sizes',
    (tester) async {
      for (final size in const [
        Size(731, 411),
        Size(1095, 616),
        Size(1920, 1080),
        Size(411, 731),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(home: ScoringPage(matchId: 'unified-responsive')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.byKey(const Key('scoring-scoreboard'))).right,
          lessThanOrEqualTo(size.width),
        );
        for (final key in const [
          'blue-score-1',
          'blue-score-2',
          'blue-score-3',
          'red-score-1',
          'red-score-2',
          'red-score-3',
          'blue-miss',
          'red-miss',
        ]) {
          expect(
            tester.getSize(find.byKey(Key(key))).height,
            greaterThanOrEqualTo(48),
          );
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('landscape side actions form one evenly spaced vertical column', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(731, 411));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'vertical-actions')),
    );

    for (final side in const ['blue', 'red']) {
      final rects = [
        for (final action in const ['score-1', 'score-2', 'score-3', 'miss'])
          tester.getRect(find.byKey(Key('$side-$action'))),
      ];
      final x = rects.first.center.dx;
      for (final rect in rects.skip(1)) {
        expect(rect.center.dx, closeTo(x, 0.5));
      }
      for (var index = 1; index < rects.length; index++) {
        expect(rects[index].top, greaterThan(rects[index - 1].bottom));
      }
      final centerGaps = [
        for (var index = 1; index < rects.length; index++)
          rects[index].center.dy - rects[index - 1].center.dy,
      ];
      for (final gap in centerGaps.skip(1)) {
        expect(gap, closeTo(centerGaps.first, 0.5));
      }
    }
  });

  testWidgets('scoreboard aligns team scores with their side action columns', (
    tester,
  ) async {
    const size = Size(731, 411);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'symmetric-scoreboard')),
    );

    final blue = tester.getRect(find.text('蓝方 0'));
    final leave = tester.getRect(find.byKey(const Key('scoring-leave')));
    final timer = tester.getRect(find.text('无计时'));
    final undo = tester.getRect(find.byKey(const Key('scoring-undo')));
    final more = tester.getRect(find.byKey(const Key('scoring-more')));
    final finish = tester.getRect(find.byKey(const Key('scoring-finish')));
    final red = tester.getRect(find.text('0 红方'));
    final blueColumn = tester.getRect(find.byKey(const Key('blue-score-1')));
    final redColumn = tester.getRect(find.byKey(const Key('red-score-1')));

    expect(timer.center.dx, closeTo(size.width / 2, 0.5));
    expect(blue.center.dx, closeTo(blueColumn.center.dx, 0.5));
    expect(red.center.dx, closeTo(redColumn.center.dx, 0.5));
    expect(blue.center.dx, lessThan(leave.center.dx));
    expect(leave.center.dx, lessThan(undo.center.dx));
    expect(undo.center.dx, lessThan(timer.center.dx));
    final foul = tester.getRect(find.byKey(const Key('scoring-foul')));
    expect(timer.center.dx, lessThan(foul.center.dx));
    expect(foul.center.dx, lessThan(more.center.dx));
    expect(more.center.dx, lessThan(finish.center.dx));
    expect(finish.center.dx, lessThan(red.center.dx));
    expect(finish.overlaps(red), isFalse);
  });

  testWidgets('portrait scoreboard aligns teams without overlapping controls', (
    tester,
  ) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'portrait-scoreboard')),
    );

    final blue = tester.getRect(find.text('蓝方 0'));
    final red = tester.getRect(find.text('0 红方'));
    final timer = tester.getRect(find.text('无计时'));
    final controls = [
      tester.getRect(find.byKey(const Key('scoring-leave'))),
      tester.getRect(find.byKey(const Key('scoring-undo'))),
      tester.getRect(find.byKey(const Key('scoring-foul'))),
      tester.getRect(find.byKey(const Key('scoring-more'))),
      tester.getRect(find.byKey(const Key('scoring-finish'))),
    ];
    final blueColumn = tester.getRect(find.byKey(const Key('blue-score-1')));
    final redColumn = tester.getRect(find.byKey(const Key('red-score-1')));

    expect(timer.center.dx, closeTo(size.width / 2, 0.5));
    expect(blue.center.dx, closeTo(blueColumn.center.dx, 0.5));
    expect(red.center.dx, closeTo(redColumn.center.dx, 0.5));
    for (final control in controls) {
      expect(blue.overlaps(control), isFalse);
      expect(red.overlaps(control), isFalse);
      expect(timer.overlaps(control), isFalse);
    }
  });

  testWidgets('finish control stays clear of the red score at 600x400', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'finish-spacing-600')),
    );

    final finish = tester.getRect(find.byKey(const Key('scoring-finish')));
    final red = tester.getRect(find.text('0 红方'));
    expect(finish.overlaps(red), isFalse);
    expect(finish.right, lessThan(red.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled motion uses an immediate static location outline', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'unified-reduced-motion')
      ..addScore(side: TeamSide.blue, points: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ScoringPage(controller: controller),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('blue-score-2-location')), findsOneWidget);
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const Key('blue-score-2-location-affordance')),
          )
          .duration,
      Duration.zero,
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.textContaining('2 秒'), findsNothing);
  });

  testWidgets('court-first score failure retains draft and retries in place', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      var failNext = false;
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (failNext && point == MatchCommandFailurePoint.beforeCommit) {
            failNext = false;
            throw StateError('court-first score failed');
          }
        },
      );
      final projection = await service.start(
        _startPageCommand('page-court-first-score-failure'),
      );
      final controller = ScoringController.fromCommittedProjection(
        projection,
        service,
      );
      failNext = true;
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await tester.tap(find.byKey(const Key('blue-score-2')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      expect(controller.courtFirstShotDraft, isNotNull);
      expect(find.byType(SnackBarAction), findsOneWidget);
      expect(
        tester
            .widget<ScoringMotionOverlay>(find.byType(ScoringMotionOverlay))
            .coordinator
            .pendingCount,
        0,
      );
      final retryAction = tester.widget<SnackBarAction>(
        find.byType(SnackBarAction),
      );
      retryAction.onPressed();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(controller.courtFirstShotDraft, isNull);
      expect(await database.select(database.matchEvents).get(), hasLength(1));
      final overlay = tester.widget<ScoringMotionOverlay>(
        find.byType(ScoringMotionOverlay),
      );
      expect(overlay.coordinator.pendingCount, 1);
      expect(overlay.coordinator.active, isNotNull);
      expect(
        tester.widget<CourtView>(find.byType(CourtView)).hiddenShotLocationIds,
        hasLength(1),
      );

      expect(find.byType(SnackBarAction), findsNothing);
      await tester.pump(const Duration(milliseconds: 800));
      expect(overlay.coordinator.pendingCount, 0);

      await tester.tap(find.byKey(const Key('scoring-undo')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('scoring-undo')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      final eventRows = await database.select(database.matchEvents).get();
      final locationRows = await database.select(database.shotLocations).get();
      expect(eventRows, hasLength(1));
      expect(eventRows.single.isDeleted, isTrue);
      expect(locationRows, hasLength(1));
      expect(locationRows.single.isConfirmed, isFalse);
      expect(controller.state.score.blueScore, 0);
      expect(
        controller.state.events.where((event) => !event.isDeleted),
        isEmpty,
      );

      retryAction.onPressed();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(overlay.coordinator.pendingCount, 0);
      expect(
        tester.widget<CourtView>(find.byType(CourtView)).hiddenShotLocationIds,
        isEmpty,
      );
      expect(
        (await database.select(database.matchEvents).get()).single.isDeleted,
        isTrue,
      );
      expect(
        (await database.select(database.shotLocations).get())
            .single
            .isConfirmed,
        isFalse,
      );
      expect(controller.state.score.blueScore, 0);
    });
  });

  testWidgets('score-first attach failure keeps the window and retries', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      var failNext = false;
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (failNext && point == MatchCommandFailurePoint.beforeCommit) {
            failNext = false;
            throw StateError('attach failed');
          }
        },
      );
      final projection = await service.start(
        _startPageCommand('page-attach-failure'),
      );
      final controller = ScoringController.fromCommittedProjection(
        projection,
        service,
      );
      await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
      failNext = true;
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      expect(controller.locationSupplementWindow, isNotNull);
      expect(find.byType(SnackBarAction), findsOneWidget);
      expect(
        tester
            .widget<ScoringMotionOverlay>(find.byType(ScoringMotionOverlay))
            .coordinator
            .pendingCount,
        0,
      );
      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(controller.locationSupplementWindow, isNull);
      expect(await database.select(database.shotLocations).get(), hasLength(1));
    });
  });

  testWidgets(
    'court-first miss failure keeps the draft and retries from the rail',
    (tester) async {
      await withTestDatabase((database) async {
        var failNext = false;
        final service = MatchCommandService(
          database,
          failureInjector: (point) {
            if (failNext && point == MatchCommandFailurePoint.beforeCommit) {
              failNext = false;
              throw StateError('miss failed');
            }
          },
        );
        final projection = await service.start(
          _startPageCommand('page-court-first-miss-failure'),
        );
        final controller = ScoringController.fromCommittedProjection(
          projection,
          service,
        );
        failNext = true;
        await tester.pumpWidget(
          MaterialApp(home: ScoringPage(controller: controller)),
        );
        await tester.tapAt(
          tester.getCenter(find.byKey(const Key('scoring-court'))),
        );
        await tester.tap(find.byKey(const Key('red-miss')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();

        expect(controller.courtFirstShotDraft, isNotNull);
        expect(find.byType(SnackBarAction), findsOneWidget);
        tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        expect(controller.courtFirstShotDraft, isNull);
        final events = await database.select(database.matchEvents).get();
        expect(events.single.outcome, ShotOutcome.missed.name);
      });
    },
  );

  testWidgets('More note failure shows inline retry and closes on success', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      var failNext = false;
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (failNext && point == MatchCommandFailurePoint.beforeCommit) {
            failNext = false;
            throw StateError('note failed');
          }
        },
      );
      final projection = await service.start(
        _startPageCommand('page-more-note-failure'),
      );
      final controller = ScoringController.fromCommittedProjection(
        projection,
        service,
      );
      failNext = true;
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );
      await tester.tap(find.byKey(const Key('scoring-more')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('more-note')));
      await tester.tap(find.byKey(const Key('more-note')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('text-entry-field')),
        'timeout',
      );
      await tester.tap(find.byKey(const Key('text-entry-confirm')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      expect(find.byKey(const Key('scoring-more-sheet')), findsOneWidget);
      expect(find.byKey(const Key('more-inline-retry')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('more-inline-retry')));
      await tester.tap(find.byKey(const Key('more-inline-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scoring-more-sheet')), findsNothing);
      expect(
        (await database.select(database.matchEvents).get()).single.note,
        'timeout',
      );
    });
  });

  testWidgets('target finish failure keeps confirmation flow retryable', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final start = await service.start(
        _startPageCommand('page-more-finish-failure', targetScore: 2),
      );
      final projection = await service.record(
        RecordMatchEventCommand(
          matchId: start.match.id,
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: DateTime.utc(2026, 8, 23, 9, 1),
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        projection,
        service,
      );
      var failNext = true;
      var finishCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            onFinishDecision: (_, _) async {
              finishCalls++;
              if (failNext) {
                failNext = false;
                throw StateError('finish failed');
              }
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('scoring-decision-finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('操作失败，请重试。'), findsOneWidget);
      expect(controller.state.decision, isNotNull);
      await tester.tap(find.byKey(const Key('scoring-decision-finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
      await tester.pumpAndSettle();
      expect(finishCalls, 2);
      expect(find.byKey(const Key('scoring-finish-confirm')), findsNothing);
    });
  });

  testWidgets('team score buttons meet contrast in light and dark themes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHoopitoTheme(brightness: brightness),
          home: SizedBox(
            width: 400,
            height: 500,
            child: Row(
              children: [
                for (final side in TeamSide.values)
                  Expanded(
                    child: ScoreSidePanel(
                      side: side,
                      name: side.name,
                      score: 0,
                      fouls: 0,
                      onScore: (_) {},
                      onMiss: () {},
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      for (final side in TeamSide.values) {
        final score = tester.widget<FilledButton>(
          find.byKey(Key('${side.name}-score-1')),
        );
        final background = score.style?.backgroundColor?.resolve(const {});
        final foreground = score.style?.foregroundColor?.resolve(const {});
        expect(background, isNotNull);
        expect(foreground, isNotNull);
        expect(
          _contrastRatio(foreground!, background!),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });

  testWidgets('disabled rail actions use local muted styling and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHoopitoTheme(),
        home: ScoreSidePanel(
          side: TeamSide.blue,
          name: 'Blue',
          score: 0,
          fouls: 0,
          scoreEnabled: false,
          missEnabled: false,
          onScore: (_) {},
          onMiss: () {},
        ),
      ),
    );

    final muted = const HoopitoEditorialTheme.light().mutedInk;
    for (final key in const [Key('blue-score-1'), Key('blue-miss')]) {
      final target = find.byKey(key);
      final button = tester.widget<ButtonStyleButton>(target);
      expect(
        button.style?.foregroundColor?.resolve(const {WidgetState.disabled}),
        muted,
      );
      expect(
        button.style?.side?.resolve(const {WidgetState.disabled})?.color,
        muted,
      );
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: target, matching: find.byType(Opacity)).first,
            )
            .opacity,
        lessThan(1),
      );
      expect(
        tester.getSemantics(target).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
    }
    semantics.dispose();
  });

  testWidgets('scoring page shows court-first landscape controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'match-1')),
    );

    expect(find.text('蓝方 0'), findsOneWidget);
    expect(find.text('0 红方'), findsOneWidget);
    expect(find.text('蓝方'), findsNothing);
    expect(find.text('红方'), findsNothing);
    expect(find.text('犯规 0'), findsNWidgets(2));
    expect(find.text('犯规'), findsOneWidget);
    expect(find.text('未命中'), findsNWidgets(2));
    expect(find.text('+1'), findsNWidgets(2));
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('+3'), findsNWidgets(2));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('scoring page does not overflow on emulator landscape size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'match-1')),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('scoring-foul')), findsOneWidget);
    expect(find.byKey(const Key('red-miss')), findsOneWidget);
    expect(find.byKey(const Key('blue-miss')), findsOneWidget);
  });

  testWidgets('timer-disabled scoring hides clock commands and ticks', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final start = await service.start(
        _startPageCommand('page-no-timer', timerEnabled: false),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            clockTick: const Duration(milliseconds: 10),
          ),
        ),
      );

      expect(controller.state.timerEnabled, isFalse);
      expect(find.text('无计时'), findsOneWidget);
      await tester.tap(find.byKey(const Key('scoring-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('more-pause')), findsNothing);
      expect(find.byKey(const Key('more-resume')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('无计时'), findsOneWidget);
    });
  });

  testWidgets(
    'winning score keeps the court available until its location is confirmed',
    (tester) async {
      final anchor = DateTime.utc(2026, 8, 28, 9);
      await withTestDatabase((database) async {
        final service = MatchCommandService(database, now: () => anchor);
        final start = await service.start(
          _startPageCommand(
            'winning-score-location-first',
            targetScore: 2,
            createdAt: anchor,
            startedAt: anchor,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
          nowUtc: () => anchor,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ScoringPage(
              controller: controller,
              clockNowUtc: () => anchor,
              onFinishDecision: (_, _) async {},
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('red-score-2')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();

        expect(controller.state.decision, isNotNull);
        expect(controller.locationSupplementWindow, isNotNull);
        expect(find.byKey(const Key('scoring-decision-dock')), findsNothing);
        expect(find.textContaining('补充红方 +2 落点'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('scoring-finish')))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('red-score-1')))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(find.byKey(const Key('scoring-foul')))
              .onPressed,
          isNull,
        );
        await tester.tap(find.byKey(const Key('scoring-more')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('more-note')));
        expect(
          tester
              .widget<EditorialIndexRow>(find.byKey(const Key('more-note')))
              .onTap,
          isNull,
        );
        Navigator.of(tester.element(find.byType(ScoringPage))).pop();
        await tester.pumpAndSettle();

        await tester.tapAt(
          tester.getCenter(find.byKey(const Key('scoring-court'))),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();

        expect(controller.locationSupplementWindow, isNull);
        expect(controller.state.shotLocations, hasLength(1));
        expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('scoring-finish')))
              .onPressed,
          isNotNull,
        );
      });
    },
  );

  testWidgets('winning score decision appears after location time expires', (
    tester,
  ) async {
    final anchor = DateTime.utc(2026, 8, 28, 9);
    var now = anchor;
    await withTestDatabase((database) async {
      final service = MatchCommandService(database, now: () => now);
      final start = await service.start(
        _startPageCommand(
          'winning-score-location-expiry',
          targetScore: 2,
          createdAt: anchor,
          startedAt: anchor,
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
        nowUtc: () => now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            clockNowUtc: () => now,
            onFinishDecision: (_, _) async {},
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('red-score-2')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      expect(controller.locationSupplementWindow, isNotNull);
      expect(find.byKey(const Key('scoring-decision-dock')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('scoring-finish')))
            .onPressed,
        isNull,
      );

      now = anchor.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));

      expect(controller.locationSupplementWindow, isNull);
      expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('scoring-finish')))
            .onPressed,
        isNotNull,
      );
    });
  });

  testWidgets(
    'pending decision exposes explicit continue and confirmed finish actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(731, 411));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        await service.start(
          _startPageCommand('decision-actions', targetScore: 2),
        );
        final projection = await service.record(
          RecordMatchEventCommand(
            commandId: 'decision-actions-score',
            matchId: 'decision-actions',
            eventId: 'decision-actions-score-event',
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: DateTime.utc(2026, 8, 23, 9, 1),
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          projection,
          service,
        );
        var continueCalls = 0;
        var finishCalls = 0;
        var confirmedRedScore = -1;
        var confirmedBlueScore = -1;

        await tester.pumpWidget(
          MaterialApp(
            home: ScoringPage(
              controller: controller,
              onContinueDecision: () async => continueCalls++,
              onFinishDecision: (redScore, blueScore) async {
                finishCalls++;
                confirmedRedScore = redScore;
                confirmedBlueScore = blueScore;
              },
            ),
          ),
        );

        expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);
        expect(find.textContaining('Red 2 : 0 Blue'), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final key in const <String>[
          'scoring-decision-continue',
          'scoring-decision-finish',
        ]) {
          final rect = tester.getRect(find.byKey(Key(key)));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(411));
          expect(rect.height, greaterThanOrEqualTo(48));
        }

        await tester.tap(find.byKey(const Key('scoring-decision-continue')));
        await tester.pumpAndSettle();
        expect(continueCalls, 1);
        expect(finishCalls, 0);

        await tester.tap(find.byKey(const Key('scoring-decision-finish')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('scoring-finish-confirm')), findsOneWidget);
        expect(find.textContaining('Red 2 : 0 Blue'), findsWidgets);
        await tester.tap(find.byKey(const Key('scoring-finish-cancel')));
        await tester.pumpAndSettle();
        expect(finishCalls, 0);

        await tester.tap(find.byKey(const Key('scoring-decision-finish')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
        await tester.pumpAndSettle();
        expect(confirmedRedScore, 2);
        expect(confirmedBlueScore, 0);
        expect(finishCalls, 1);
      });
    },
  );

  for (final locale in ['zh', 'en']) {
    testWidgets(
      '$locale command-backed scoring page renders the projection rule hints',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await withTestDatabase((database) async {
          final service = MatchCommandService(database);
          final start = await service.start(
            StartMatchCommand(
              commandId: 'page-command-hints-start',
              matchId: 'page-command-hints',
              redName: 'Red',
              blueName: 'Blue',
              ruleTemplate: const RuleTemplate(
                id: 'page-command-hints-rule',
                name: 'Page command hints',
                scoreButtons: [1, 2, 3],
                targetScore: 3,
                possessionHintEnabled: true,
                possessionPolicy: PossessionPolicy.switchAfterMade,
              ),
              recordingMode: RecordingMode.simple,
              trackingCoverage: TrackingCoverage.locations,
              createdAt: DateTime.utc(2026, 8, 23, 9),
              startedAt: DateTime.utc(2026, 8, 23, 9),
            ),
          );
          final controller = ScoringController.fromCommittedProjection(
            start,
            service,
          );
          await controller.recordScoreCommitted(side: TeamSide.red, points: 2);

          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ScoringPage(controller: controller),
            ),
          );

          expect(find.byKey(const Key('scoring-rule-hints')), findsOneWidget);
          expect(
            find.textContaining(
              locale == 'zh' ? '蓝方 · 球权建议' : 'Blue · Possession suggested',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(locale == 'zh' ? '赛点' : 'Match point'),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              locale == 'zh' ? '补充红方 +2' : 'Red +2: add location',
            ),
            findsOneWidget,
          );
        });
      },
    );
  }

  testWidgets('failed decision finish stays available and reports failure', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      await service.start(
        _startPageCommand('decision-failure', targetScore: 2),
      );
      final projection = await service.record(
        RecordMatchEventCommand(
          commandId: 'decision-failure-score',
          matchId: 'decision-failure',
          eventId: 'decision-failure-score-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: DateTime.utc(2026, 8, 23, 9, 1),
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        projection,
        service,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            onFinishDecision: (_, _) =>
                Future<void>.error(StateError('offline')),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('scoring-decision-finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('操作失败，请重试。'), findsOneWidget);
      expect(find.byKey(const Key('scoring-decision-finish')), findsOneWidget);
    });
  });

  testWidgets('failed decision continue shows retry and keeps the decision', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      await service.start(
        _startPageCommand('decision-continue-retry', targetScore: 2),
      );
      final projection = await service.record(
        RecordMatchEventCommand(
          commandId: 'decision-continue-retry-score',
          matchId: 'decision-continue-retry',
          eventId: 'decision-continue-retry-score-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: DateTime.utc(2026, 8, 23, 9, 1),
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        projection,
        service,
      );
      final command = ContinueMatchCommand(
        commandId: 'decision-continue-retry-command',
        matchId: 'decision-continue-retry',
        occurredAt: DateTime.utc(2026, 8, 23, 9, 2),
      );
      var attempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            onContinueDecision: () async {
              attempts++;
              if (attempts == 1) throw StateError('offline');
              await service.continueMatch(command);
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('scoring-decision-continue')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);
      expect(find.byType(SnackBarAction), findsOneWidget);
      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      expect(attempts, 2);
      expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);
    });
  });

  testWidgets('committed scoring feedback runs after the event is persisted', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final commandService = MatchCommandService(database);
      final projection = await commandService.start(
        _startPageCommand('feedback-order'),
      );
      final controller = ScoringController.fromCommittedProjection(
        projection,
        commandService,
      );
      final observedEventCounts = <int>[];
      final platform = _RecordingFeedbackPlatform(
        onHaptic: () async {
          observedEventCounts.add(
            (await database.select(database.matchEvents).get()).length,
          );
        },
      );
      final feedback = ScoringFeedbackService(
        ScoringFeedbackPreferencesRepository(database),
        platform: platform,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            onActionCommitted: feedback.emitCommitted,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('red-score-2')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );

      expect(observedEventCounts, [1]);
    });
  });

  testWidgets('compact score controls and court remain in the first viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(731, 411));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'compact-first-viewport')),
    );

    for (final key in <String>[
      'blue-score-1',
      'blue-score-2',
      'blue-score-3',
      'blue-miss',
      'red-score-1',
      'red-score-2',
      'red-score-3',
      'red-miss',
    ]) {
      final rect = tester.getRect(find.byKey(Key(key)));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(411));
      expect(rect.height, greaterThanOrEqualTo(48));
    }
    expect(find.text('蓝方 0'), findsOneWidget);
    expect(find.text('0 红方'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('scoring-court'))).height,
      greaterThanOrEqualTo(100),
    );
  });

  testWidgets(
    'compact court-first draft preserves court and commits through side panel',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(731, 411));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = ScoringController(
        setup: const MatchSetup(
          matchId: 'compact-detailed',
          redName: '红方',
          blueName: '蓝方',
          ruleTemplateId: 'free',
          targetScore: null,
          timerEnabled: false,
          timeLimitMinutes: 10,
          winByTwo: false,
          recordingMode: RecordingMode.detailed,
          trackingCoverage: TrackingCoverage.locations,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await tester.pump();

      expect(controller.courtFirstShotDraft, isNotNull);
      expect(find.text('请选择蓝方或红方得分'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('scoring-court'))).height,
        greaterThanOrEqualTo(100),
      );
      await tester.tap(find.byKey(const Key('blue-score-2')));
      await tester.pumpAndSettle();
      expect(controller.courtFirstShotDraft, isNull);
      expect(controller.state.shotLocations, hasLength(1));
    },
  );

  testWidgets('score-first location stays on court without a secondary dock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(731, 411));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final start = await service.start(
        _startPageCommand('page-pending-court'),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
      );
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );
      await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
      await tester.pump();

      expect(controller.locationSupplementWindow, isNotNull);
      expect(find.byKey(const Key('red-score-2-location')), findsOneWidget);
      expect(find.byKey(const Key('scoring-court')), findsOneWidget);
      final court = tester.getRect(find.byKey(const Key('scoring-court')));
      expect(court.height, greaterThan(0));
      await tester.tapAt(court.center);
      await tester.pumpAndSettle();
      expect(controller.locationSupplementWindow, isNull);
      expect(controller.state.shotLocations, hasLength(1));
    });
  });

  testWidgets('compact header accommodates long player names', (tester) async {
    await tester.binding.setSurfaceSize(const Size(731, 411));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ScoringController(
      setup: const MatchSetup(
        matchId: 'compact-header',
        redName: '集成测试红方长名称',
        blueName: '集成测试蓝方长名称',
        ruleTemplateId: 'free',
        targetScore: null,
        timerEnabled: false,
        timeLimitMinutes: 10,
        winByTwo: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(controller: controller, onOpenReplay: () {}),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('集成测试蓝方长名称 0'), findsOneWidget);
    expect(find.text('0 集成测试红方长名称'), findsOneWidget);
  });

  testWidgets('scoring page does not overflow while pending bar is visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ScoringController(matchId: 'match-1')
      ..addScore(side: TeamSide.red, points: 2);

    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('scoring-court')), findsOneWidget);
  });

  testWidgets('pending location controls do not resize the court', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1095, 616));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ScoringController(matchId: 'match-1');

    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );
    controller.addScore(side: TeamSide.red, points: 2);
    await tester.pump();
    final sizeWithPending = tester.getSize(find.byType(CourtView));

    expect(sizeWithPending.height, greaterThan(0));
    expect(find.byKey(const Key('red-score-2-location')), findsOneWidget);
  });

  testWidgets('choosing not to mark a shot records score immediately', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final anchor = DateTime.utc(2026, 8, 23, 9);
      final service = MatchCommandService(database, now: () => anchor);
      final start = await service.start(
        StartMatchCommand(
          commandId: 'page-one-tap-start',
          matchId: 'page-one-tap-match',
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplate: const RuleTemplate(
            id: 'free',
            name: 'Free',
            scoreButtons: [1, 2, 3],
          ),
          recordingMode: RecordingMode.simple,
          trackingCoverage: TrackingCoverage.locations,
          createdAt: DateTime.utc(2026, 8, 23, 9),
          startedAt: DateTime.utc(2026, 8, 23, 9),
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
      );
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );

      await tester.tap(find.byKey(const Key('red-score-2')));
      await tester.pump();

      expect(controller.state.score.redScore, 2);
      expect(controller.state.pendingLocation, isNull);
      expect(await database.select(database.matchEvents).get(), hasLength(1));
    });
  });

  testWidgets('direct court tap locks a score-first marker', (tester) async {
    final controller = ScoringController(matchId: 'match-1');

    await tester.pumpWidget(
      MaterialApp(home: ScoringPage(controller: controller)),
    );

    await tester.tap(find.byKey(const Key('blue-score-3')));
    await tester.pump();
    expect(find.byKey(const Key('blue-score-3-location')), findsOneWidget);
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.pumpAndSettle();

    expect(controller.state.score.blueScore, 3);
    expect(controller.state.pendingLocation, isNull);
    expect(controller.state.shotLocations.single.side, TeamSide.blue);
    expect(controller.state.shotLocations.single.isLocked, isTrue);
  });

  testWidgets(
    'tapping score while a supplement window is open continues scoring',
    (tester) async {
      final controller = ScoringController(matchId: 'match-1');

      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );

      await tester.tap(find.byKey(const Key('red-score-2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('blue-score-3')));
      await tester.pump();

      expect(find.byKey(const Key('scoring-action-rejected')), findsNothing);
      expect(controller.state.score.redScore, 2);
      expect(controller.state.score.blueScore, 3);
    },
  );

  testWidgets(
    'rapid command-backed scores commit in tap order without a modal',
    (tester) async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = await service.start(_startPageCommand('page-rapid'));
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
        );
        await tester.pumpWidget(
          MaterialApp(home: ScoringPage(controller: controller)),
        );

        await tester.tap(find.byKey(const Key('blue-score-1')));
        await tester.tap(find.byKey(const Key('red-score-2')));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );

        final events = await database.select(database.matchEvents).get();
        expect(events.map((event) => event.points), [1, 2]);
        expect(controller.state.score.blueScore, 1);
        expect(controller.state.score.redScore, 2);
      });
    },
  );

  testWidgets('score-first direct court tap confirms or leaves the next shot', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final start = await service.start(_startPageCommand('page-locate'));
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
      );
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );

      await tester.tap(find.byKey(const Key('red-score-2')));
      await tester.pump();
      expect(find.byKey(const Key('red-score-2-location')), findsOneWidget);
      expect(find.byKey(const Key('scoring-court')), findsOneWidget);

      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await tester.pumpAndSettle();
      expect(controller.state.pendingLocation, isNull);
      expect(await database.select(database.shotLocations).get(), hasLength(1));

      await controller.recordScoreCommitted(side: TeamSide.blue, points: 1);
      await tester.pump();
      await tester.tap(find.byKey(const Key('scoring-undo')));
      await tester.pumpAndSettle();
      expect(controller.state.pendingLocation, isNull);
      expect(await database.select(database.shotLocations).get(), hasLength(1));
    });
  });

  testWidgets('detailed mode is court-first and commits corrected draft once', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final start = await service.start(
        _startPageCommand(
          'page-detailed',
          recordingMode: RecordingMode.detailed,
        ),
      );
      final withPossession = await service.record(
        RecordMatchEventCommand(
          matchId: start.match.id,
          type: EventKind.possession,
          side: TeamSide.blue,
          points: 0,
          occurredAt: DateTime.utc(2026, 8, 23, 9, 1),
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        withPossession,
        service,
      );
      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('blue-score-2')))
            .onPressed,
        isNotNull,
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await tester.pump();
      expect(controller.detailedShotDraft, isNotNull);
      expect(find.text('请选择蓝方或红方得分'), findsOneWidget);
      await tester.tap(find.byKey(const Key('red-score-2')));
      await tester.pumpAndSettle();

      final events = await database.select(database.matchEvents).get();
      final locations = await database.select(database.shotLocations).get();
      expect(controller.detailedShotDraft, isNull);
      expect(events, hasLength(2));
      expect(events.last.side, TeamSide.red.name);
      expect(events.last.points, 2);
      expect(events.last.outcome, ShotOutcome.made.name);
      expect(locations, hasLength(1));
      expect(locations.single.eventId, events.last.id);
    });
  });

  testWidgets(
    'detailed draft cancel leaves the committed projection untouched',
    (tester) async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = await service.start(
          _startPageCommand(
            'page-detailed-cancel',
            recordingMode: RecordingMode.detailed,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
        );
        await tester.pumpWidget(
          MaterialApp(home: ScoringPage(controller: controller)),
        );
        await tester.tapAt(
          tester.getCenter(find.byKey(const Key('scoring-court'))),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('scoring-undo')));
        await tester.pump();

        expect(controller.detailedShotDraft, isNull);
        expect(controller.state.events, isEmpty);
        expect(await database.select(database.matchEvents).get(), isEmpty);
        expect(await database.select(database.shotLocations).get(), isEmpty);
      });
    },
  );

  testWidgets('More records possession and free throw; top control pauses', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final anchor = DateTime.utc(2026, 8, 23, 9);
      final service = MatchCommandService(database, now: () => anchor);
      final start = await service.start(
        _startPageCommand(
          'page-more-actions',
          timerEnabled: true,
          clockMode: ClockMode.countUp,
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            clockNowUtc: () => anchor.add(const Duration(seconds: 1)),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('scoring-more')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('more-possession-blue')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('scoring-more-sheet')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('more-possession-blue')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('scoring-more')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('more-blue-free-throw-made')),
      );
      await tester.tap(find.byKey(const Key('more-blue-free-throw-made')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('scoring-finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('match-controls-pause')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();

      final events = await database.select(database.matchEvents).get();
      expect(
        events.map((event) => event.type),
        containsAll(<String>[
          EventKind.possession.name,
          EventKind.freeThrow.name,
          EventKind.pause.name,
        ]),
      );
      expect(controller.currentPossession, TeamSide.blue);
      expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
      expect(find.text('比赛已暂停'), findsOneWidget);
    });
  });

  testWidgets('compact unified workspace keeps primary targets at 48dp', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(731, 411));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: ScoringPage(matchId: 'compact-actions')),
    );

    for (final key in <String>[
      'blue-score-1',
      'blue-score-2',
      'blue-score-3',
      'blue-miss',
      'red-score-1',
      'red-score-2',
      'red-score-3',
      'red-miss',
      'scoring-undo',
    ]) {
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(find.byKey(const Key('more-pause')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final textScaler in [TextScaler.noScaling, const TextScaler.linear(2)]) {
    testWidgets(
      'portrait scoring keeps every primary action visible at ${textScaler == TextScaler.noScaling ? 'normal' : '200 percent'} text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const insets = EdgeInsets.only(top: 24, bottom: 24);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: textScaler,
                padding: insets,
                viewPadding: insets,
              ),
              child: child!,
            ),
            home: const ScoringPage(matchId: 'portrait-primary-actions'),
          ),
        );
        await tester.pumpAndSettle();

        for (final side in ['blue', 'red']) {
          final rail = tester.getRect(find.byKey(Key('$side-action-rail')));
          expect(rail.top, greaterThanOrEqualTo(insets.top));
          expect(rail.bottom, lessThanOrEqualTo(844 - insets.bottom));
          for (final action in ['score-1', 'score-2', 'score-3', 'miss']) {
            final rect = tester.getRect(find.byKey(Key('$side-$action')));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(
              rail.contains(rect.topLeft) && rail.contains(rect.bottomRight),
              isTrue,
              reason:
                  '$side $action must be visible inside the rail on first paint',
            );
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('compact scoring remains usable at 200 percent text size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(731, 411));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ScoringPage(matchId: 'compact-large-text'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(ScoreSidePanel).first).width,
      inInclusiveRange(112, 128),
    );
    expect(
      tester.getSize(find.byKey(const Key('scoring-court'))).height,
      greaterThanOrEqualTo(100),
    );
    expect(
      tester.getSize(find.byKey(const Key('scoring-court'))).width,
      greaterThanOrEqualTo(320),
    );
  });

  testWidgets('scoreboard reflows controls at narrow width and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ScoringPage(
          matchId: 'narrow-large-text-scoreboard',
          onRequestLeave: () async {},
          onOpenReplay: () {},
          onResumeClock: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final scoreboard = find.byKey(const Key('scoring-scoreboard'));
    expect(scoreboard, findsOneWidget);
    expect(tester.getRect(scoreboard).right, lessThanOrEqualTo(390));
    expect(tester.getSize(scoreboard).height, greaterThanOrEqualTo(48));
  });

  testWidgets('compact scoring keeps primary controls within safe insets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(731, 411));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const insets = EdgeInsets.only(top: 24, bottom: 24);
    final controller = ScoringController(
      setup: const MatchSetup(
        matchId: 'compact-insets',
        redName: '红方',
        blueName: '蓝方',
        ruleTemplateId: 'free',
        targetScore: null,
        timerEnabled: false,
        timeLimitMinutes: 10,
        winByTwo: false,
        recordingMode: RecordingMode.simple,
        trackingCoverage: TrackingCoverage.locations,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(731, 411),
            padding: insets,
            viewPadding: insets,
          ),
          child: ScoringPage(controller: controller),
        ),
      ),
    );

    final safeTop = insets.top;
    final safeBottom = 411 - insets.bottom;
    for (final key in <String>[
      'blue-score-1',
      'blue-score-2',
      'blue-score-3',
      'blue-miss',
      'red-score-1',
      'red-score-2',
      'red-score-3',
      'red-miss',
    ]) {
      final control = find.byKey(Key(key));
      final rect = tester.getRect(control);
      expect(rect.top, greaterThanOrEqualTo(safeTop));
      expect(rect.bottom, lessThanOrEqualTo(safeBottom));
      expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    }
    expect(
      tester.getSize(find.byKey(const Key('scoring-court'))).height,
      greaterThanOrEqualTo(100),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('clock display projects elapsed time without database ticks', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final anchor = DateTime.utc(2026, 8, 23, 9);
      final service = MatchCommandService(database, now: () => anchor);
      final start = await service.start(
        _startPageCommand(
          'page-clock',
          timerEnabled: true,
          clockMode: ClockMode.countUp,
          createdAt: anchor,
          startedAt: anchor,
        ),
      );
      var now = anchor.add(const Duration(seconds: 2));
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(controller: controller, clockNowUtc: () => now),
        ),
      );
      expect(find.text('00:02'), findsOneWidget);
      now = anchor.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:05'), findsOneWidget);
    });
  });

  testWidgets('clock display announces overtime from committed projection', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final anchor = DateTime.utc(2026, 8, 23, 9);
      final service = MatchCommandService(database, now: () => anchor);
      await service.start(
        _startPageCommand(
          'page-overtime',
          timerEnabled: true,
          clockMode: ClockMode.countdown,
          regulationSeconds: 60,
          createdAt: anchor,
          startedAt: anchor,
        ),
      );
      await MatchCommandService(
        database,
        now: () => anchor.add(const Duration(seconds: 60)),
      ).readClock('page-overtime');
      final continued =
          await MatchCommandService(
            database,
            now: () => anchor.add(const Duration(seconds: 12)),
          ).continueMatch(
            ContinueMatchCommand(
              commandId: 'page-overtime-continue',
              matchId: 'page-overtime',
              occurredAt: anchor.add(const Duration(seconds: 12)),
            ),
          );
      final controller = ScoringController.fromCommittedProjection(
        continued,
        service,
      );
      for (final locale in const [Locale('zh'), Locale('en')]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ScoringPage(
              controller: controller,
              clockNowUtc: () => anchor.add(const Duration(seconds: 12)),
            ),
          ),
        );
        await tester.pump();
        final expected = locale.languageCode == 'zh'
            ? '加时赛 00:00'
            : 'Overtime 00:00';
        expect(find.text(expected), findsOneWidget);
      }
    });
  });

  for (final mode in [ClockMode.countUp, ClockMode.countdown]) {
    testWidgets(
      '${mode.name} clock counts elapsed time once after scoring and re-entry',
      (tester) async {
        await withTestDatabase((database) async {
          final anchor = DateTime.utc(2026, 8, 23, 9);
          var now = anchor;
          final service = MatchCommandService(database, now: () => now);
          final start = await service.start(
            _startPageCommand(
              'page-clock-${mode.name}',
              timerEnabled: true,
              clockMode: mode,
              createdAt: anchor,
              startedAt: anchor,
            ),
          );
          final controller = ScoringController.fromCommittedProjection(
            start,
            service,
            nowUtc: () => now,
          );
          now = anchor.add(const Duration(seconds: 30));
          expect(
            await controller.recordScoreCommitted(
              side: TeamSide.blue,
              points: 2,
            ),
            isTrue,
          );
          expect(controller.clock!.elapsedSeconds, 30);
          now = anchor.add(const Duration(seconds: 32));
          await tester.pumpWidget(
            MaterialApp(
              home: ScoringPage(controller: controller, clockNowUtc: () => now),
            ),
          );
          expect(
            find.text(mode == ClockMode.countUp ? '00:32' : '09:28'),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox.shrink());
          final restored = ScoringController(
            commandService: service,
            committedProjection: await service.record(
              RecordMatchEventCommand(
                commandId: 'page-clock-${mode.name}-re-entry',
                matchId: start.match.id,
                type: EventKind.fieldGoal,
                side: TeamSide.red,
                points: 1,
                outcome: ShotOutcome.made,
                occurredAt: now,
              ),
            ),
            nowUtc: () => now,
          );
          now = anchor.add(const Duration(seconds: 40));
          await tester.pumpWidget(
            MaterialApp(
              home: ScoringPage(controller: restored, clockNowUtc: () => now),
            ),
          );
          expect(
            find.text(mode == ClockMode.countUp ? '00:40' : '09:20'),
            findsOneWidget,
          );
          final clock = await database.select(database.matchClocks).getSingle();
          expect(clock.accumulatedSeconds, 0);
          expect(clock.runningSinceUtc?.toUtc(), anchor);
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          restored.dispose();
        });
      },
    );
  }

  testWidgets('scoring page swaps injected controllers when rebuilt', (
    tester,
  ) async {
    final first = ScoringController(matchId: 'match-1');
    final second = ScoringController(matchId: 'match-2');

    await tester.pumpWidget(MaterialApp(home: ScoringPage(controller: first)));
    await tester.pumpWidget(MaterialApp(home: ScoringPage(controller: second)));

    await tester.tap(find.byKey(const Key('red-score-1')));
    await tester.pump();

    expect(first.state.events, isEmpty);
    expect(second.state.score.redScore, 1);
  });

  testWidgets('More replay opens only after score-first location is resolved', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var openCount = 0;
    final controller = ScoringController(matchId: 'match-1');

    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          controller: controller,
          onOpenReplay: () => openCount++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('scoring-more')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('more-replay')));
    await tester.tap(find.byKey(const Key('more-replay')));
    await tester.pumpAndSettle();
    expect(openCount, 1);

    await tester.tap(find.byKey(const Key('red-score-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('scoring-more')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('more-replay')));
    await tester.tap(find.byKey(const Key('more-replay')));
    await tester.pump();

    expect(openCount, 1);
    expect(
      tester
          .widget<EditorialIndexRow>(find.byKey(const Key('more-replay')))
          .onTap,
      isNull,
    );
    final replay = find.byKey(const Key('more-replay'));
    expect(
      tester.getSemantics(replay).flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: replay, matching: find.byType(Opacity)).first,
          )
          .opacity,
      lessThan(1),
    );
    final editorial = const HoopitoEditorialTheme.light();
    final rowTheme = tester.widget<Theme>(
      find.ancestor(of: replay, matching: find.byType(Theme)).first,
    );
    final disabledEditorial = rowTheme.data.extension<HoopitoEditorialTheme>();
    expect(disabledEditorial?.ink, editorial.mutedInk);
    expect(disabledEditorial?.rule, editorial.mutedInk);
    semantics.dispose();
  });

  testWidgets('top Undo awaits soft-delete for a command-backed score', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final command = StartMatchCommand(
        commandId: 'page-undo-start-command',
        matchId: 'page-undo-match',
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: 'Free',
          scoreButtons: [1, 2, 3],
        ),
        recordingMode: RecordingMode.simple,
        trackingCoverage: TrackingCoverage.locations,
        createdAt: DateTime.utc(2026, 8, 23, 9),
        startedAt: DateTime.utc(2026, 8, 23, 9),
      );
      final projection = await service.start(command);
      final controller = ScoringController.fromCommittedProjection(
        projection,
        service,
      );

      await tester.pumpWidget(
        MaterialApp(home: ScoringPage(controller: controller)),
      );
      await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
      await tester.pump();

      await tester.tap(find.byKey(const Key('scoring-undo')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );

      final event = await database.select(database.matchEvents).getSingle();
      expect(event.isDeleted, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  testWidgets('retryable confirm failure offers retry and commits location', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await withTestDatabase((database) async {
      var failNext = false;
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (failNext && point == MatchCommandFailurePoint.beforeCommit) {
            failNext = false;
            throw StateError('confirm failed once');
          }
        },
      );
      final start = await service.start(
        StartMatchCommand(
          commandId: 'page-retry-start-command',
          matchId: 'page-retry-match',
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplate: const RuleTemplate(
            id: 'free',
            name: 'Free',
            scoreButtons: [1, 2, 3],
          ),
          recordingMode: RecordingMode.simple,
          trackingCoverage: TrackingCoverage.locations,
          createdAt: DateTime.utc(2026, 8, 23, 9),
          startedAt: DateTime.utc(2026, 8, 23, 9),
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
      );
      var committedFeedbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            onActionCommitted: () => committedFeedbackCount++,
          ),
        ),
      );
      await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
      failNext = true;
      await tester.pump();
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('scoring-court'))),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();

      expect(find.text('重试'), findsOneWidget);
      expect(controller.locationSupplementWindow, isNotNull);
      final retryAction = tester.widget<SnackBarAction>(
        find.byType(SnackBarAction),
      );
      retryAction.onPressed();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();

      expect(controller.locationSupplementWindow, isNull);
      expect(await database.select(database.shotLocations).get(), hasLength(1));
      expect(committedFeedbackCount, 1);
      final overlay = tester.widget<ScoringMotionOverlay>(
        find.byType(ScoringMotionOverlay),
      );
      expect(overlay.coordinator.pendingCount, 1);
      expect(overlay.coordinator.active, isNotNull);
      expect(
        tester.widget<CourtView>(find.byType(CourtView)).hiddenShotLocationIds,
        hasLength(1),
      );
    });
  });

  testWidgets(
    'leave remains available while a local supplement window exists',
    (tester) async {
      final controller = ScoringController(matchId: 'leave-pending-local');
      controller.addScore(side: TeamSide.blue, points: 2);
      var leaveCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            onRequestLeave: () async => leaveCalls++,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('scoring-leave')));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(leaveCalls, 1);
    },
  );

  testWidgets('leave stays in scoring when pending cancellation is busy', (
    tester,
  ) async {
    await withTestDatabase((database) async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var armed = false;
      final anchor = DateTime.utc(2026, 8, 23, 9);
      final service = MatchCommandService(
        database,
        now: () => anchor,
        failureInjector: (point) async {
          if (armed && point == MatchCommandFailurePoint.beforeCommit) {
            if (!entered.isCompleted) entered.complete();
            await release.future;
          }
        },
      );
      final start = await service.start(
        _startPageCommand('leave-busy-pending'),
      );
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
        nowUtc: () => anchor,
      );
      await controller.recordScoreCommitted(side: TeamSide.blue, points: 2);
      armed = true;
      expect(controller.beginLocateLastUnlocatedShot(), isTrue);
      final confirmation = controller.confirmPendingLocation();
      await entered.future;

      var leaveCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ScoringPage(
            controller: controller,
            clockNowUtc: () => anchor,
            onRequestLeave: () async => leaveCalls++,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('scoring-leave')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('leave-cancel-pending')));
      await tester.pump();

      expect(leaveCalls, 0);
      expect(find.byType(AlertDialog), findsOneWidget);

      release.complete();
      await confirmation;
    });
  });

  testWidgets('leave is guarded while a detailed draft is uncommitted', (
    tester,
  ) async {
    final controller = ScoringController(
      setup: const MatchSetup(
        matchId: 'leave-draft-local',
        redName: '红方',
        blueName: '蓝方',
        ruleTemplateId: 'free',
        targetScore: null,
        timerEnabled: false,
        timeLimitMinutes: 10,
        winByTwo: false,
        recordingMode: RecordingMode.detailed,
        trackingCoverage: TrackingCoverage.locations,
      ),
    );
    controller.beginDetailedShot(CourtPoint(x: 0.4, y: 0.6));
    var leaveCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          controller: controller,
          onRequestLeave: () async => leaveCalls++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('scoring-leave')));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const Key('leave-stay')), findsOneWidget);
    expect(find.byKey(const Key('leave-cancel-pending')), findsOneWidget);
    expect(leaveCalls, 0);
    await tester.tap(find.byKey(const Key('leave-stay')));
    expect(leaveCalls, 0);
  });
}

Future<void> _tapFoul(WidgetTester tester, TeamSide side) async {
  await tester.tap(find.byKey(const Key('scoring-foul')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('scoring-foul-${side.name}')));
  await tester.pump();
}

class _RecordingFeedbackPlatform implements ScoringFeedbackPlatform {
  _RecordingFeedbackPlatform({required this.onHaptic});

  final Future<void> Function() onHaptic;

  @override
  Future<void> lightImpact() => onHaptic();

  @override
  Future<void> click() async {}
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

StartMatchCommand _startPageCommand(
  String id, {
  RecordingMode recordingMode = RecordingMode.simple,
  TrackingCoverage trackingCoverage = TrackingCoverage.locations,
  bool timerEnabled = false,
  ClockMode clockMode = ClockMode.countUp,
  int? regulationSeconds,
  DateTime? createdAt,
  DateTime? startedAt,
  int? targetScore,
  bool winByTwo = false,
}) {
  final anchor = createdAt ?? DateTime.utc(2026, 8, 23, 9);
  return StartMatchCommand(
    commandId: '$id-command',
    matchId: id,
    redName: 'Red',
    blueName: 'Blue',
    ruleTemplate: RuleTemplate(
      id: 'free',
      name: 'Free',
      scoreButtons: const [1, 2, 3],
      targetScore: targetScore,
      winByTwo: winByTwo,
    ),
    recordingMode: recordingMode,
    trackingCoverage: trackingCoverage,
    clockMode: clockMode,
    regulationSeconds: clockMode == ClockMode.countdown
        ? regulationSeconds ?? 600
        : null,
    timerEnabled: timerEnabled,
    createdAt: anchor,
    startedAt: startedAt ?? anchor,
  );
}
