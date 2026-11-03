import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/rules/rule_engine.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

import '../../test_helpers/test_database.dart';

final _anchor = DateTime.utc(2026, 10, 28, 9);

Future<ScoringController> _goal(
  MatchCommandService service, {
  bool recent = false,
}) async {
  await service.start(
    StartMatchCommand(
      matchId: 'goal-ui',
      redName: 'Falcons',
      blueName: 'Waves',
      ruleTemplate: const RuleTemplate(
        id: 'target',
        name: 'Target',
        scoreButtons: [1, 2, 3],
        targetScore: 11,
      ),
      recordingMode: RecordingMode.simple,
      createdAt: _anchor,
      startedAt: _anchor,
    ),
  );
  for (var i = 0; i < 5; i++) {
    await service.record(
      RecordMatchEventCommand(
        matchId: 'goal-ui',
        side: TeamSide.red,
        points: 2,
        occurredAt: _anchor,
      ),
    );
  }
  final projection = await service.record(
    RecordMatchEventCommand(
      matchId: 'goal-ui',
      side: TeamSide.red,
      points: 2,
      occurredAt: _anchor,
    ),
  );
  return ScoringController.fromCommittedProjection(
    projection,
    service,
    nowUtc: () => recent ? _anchor : _anchor.add(const Duration(seconds: 11)),
  );
}

Widget _app(
  ScoringController controller, {
  String locale = 'zh',
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => MaterialApp(
  theme: buildHoopitoTheme(brightness: brightness),
  locale: Locale(locale),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: ScoringPage(
    controller: controller,
    clockNowUtc: () => _anchor,
    onFinishDecision: (_, _) async {},
    onContinueDecision: () async {},
  ),
);

void main() {
  testWidgets(
    'last action shows the score rather than internal decision labels',
    (tester) async {
      final service = MatchCommandService(
        createTestDatabase(),
        now: () => _anchor,
      );
      final controller = await _goal(service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      final status = find.byKey(const Key('scoring-record-status'));
      expect(
        find.descendant(
          of: status,
          matching: find.textContaining('Falcons +2'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('decision:'), findsNothing);
      controller.replaceCommittedProjection(
        await service.continueMatch(
          ContinueMatchCommand(matchId: 'goal-ui', occurredAt: _anchor),
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: status,
          matching: find.textContaining('Falcons +2'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('continueTarget'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final recent in [false, true]) {
    testWidgets(
      'compatible target decision without a goal value remains usable recent=$recent',
      (tester) async {
        final service = MatchCommandService(
          createTestDatabase(),
          now: () => _anchor,
        );
        final controller = await _goal(service, recent: recent);
        addTearDown(controller.dispose);
        final state = controller.state;
        controller.replaceCommittedProjection(
          MatchDetail(
            match: Match(
              id: 'goal-ui',
              createdAt: _anchor,
              redName: state.redName,
              blueName: state.blueName,
              ruleTemplateSnapshot: const RuleTemplate(
                id: 'legacy',
                name: 'Legacy',
                scoreButtons: [1, 2, 3],
              ),
            ),
            events: state.events,
            shotLocations: const [],
            redScore: 12,
            blueScore: 0,
            redFouls: 0,
            blueFouls: 0,
            shotAttemptCount: 6,
            locatedShotCount: 0,
            decision: state.decision,
          ),
        );
        await tester.pumpWidget(_app(controller));
        expect(tester.takeException(), isNull);
        expect(find.text('已达到目标分'), findsOneWidget);
        expect(find.textContaining('Falcons 12 : 0 Waves'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'repeated finish opens one confirmation and cancel leaves decision pending',
    (tester) async {
      final service = MatchCommandService(
        createTestDatabase(),
        now: () => _anchor,
      );
      final controller = await _goal(service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      final action = tester
          .widget<FilledButton>(
            find.byKey(const Key('scoring-decision-finish')),
          )
          .onPressed!;
      action();
      action();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('scoring-finish-cancel')));
      await tester.pumpAndSettle();
      expect(controller.state.decision, isNotNull);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('scoring-decision-finish')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final locale in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(360, 740), const Size(740, 360)]) {
        testWidgets('goal confirmation $locale $brightness $size at 200%', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final service = MatchCommandService(
            createTestDatabase(),
            now: () => _anchor,
          );
          final controller = await _goal(service);
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            _app(controller, locale: locale, brightness: brightness, scale: 2),
          );
          await tester.pump();
          expect(
            find.text(locale == 'zh' ? '已达到目标分' : 'Target score reached'),
            findsOneWidget,
          );
          expect(
            find.text(locale == 'zh' ? '目标 11 分' : 'Target: 11 points'),
            findsOneWidget,
          );
          expect(
            find.text(
              locale == 'zh'
                  ? 'Falcons已达到目标分'
                  : 'Falcons has reached the target',
            ),
            findsOneWidget,
          );
          expect(find.textContaining('Falcons 12 : 0 Waves'), findsOneWidget);
          expect(
            find.text(locale == 'zh' ? '比赛结束' : 'Game finished'),
            findsNothing,
          );
          for (final key in [
            'scoring-decision-finish',
            'scoring-decision-continue',
            'scoring-decision-undo-score',
          ]) {
            await tester.ensureVisible(find.byKey(Key(key)));
            expect(
              tester.getSize(find.byKey(Key(key))).height,
              greaterThanOrEqualTo(48),
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }

  testWidgets(
    'goal is visible immediately and skip retains score then exposes confirmation',
    (tester) async {
      final service = MatchCommandService(
        createTestDatabase(),
        now: () => _anchor,
      );
      final controller = await _goal(service, recent: true);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      expect(controller.locationSupplementWindow, isNotNull);
      expect(find.byKey(const Key('scoring-target-notice')), findsOneWidget);
      expect(find.text('已达到目标分'), findsOneWidget);
      expect(find.textContaining('目标 11 分'), findsOneWidget);
      expect(find.textContaining('Falcons 12 : 0 Waves'), findsOneWidget);
      expect(find.byKey(const Key('scoring-decision-dock')), findsNothing);
      await tester.tap(find.byKey(const Key('scoring-target-skip-location')));
      await tester.pump();
      expect(controller.locationSupplementWindow, isNull);
      expect(controller.state.score.redScore, 12);
      expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('skip target location also closes an explicit pending marker', (
    tester,
  ) async {
    final service = MatchCommandService(
      createTestDatabase(),
      now: () => _anchor,
    );
    final controller = await _goal(service, recent: true);
    addTearDown(controller.dispose);
    expect(controller.beginLocateLastUnlocatedShot(), isTrue);
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const Key('scoring-target-skip-location')));
    await tester.pump();
    expect(controller.state.pendingLocation, isNull);
    expect(controller.locationSupplementWindow, isNull);
    expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'target undo after a supplement removes score and location once',
    (tester) async {
      final service = MatchCommandService(
        createTestDatabase(),
        now: () => _anchor,
      );
      final controller = await _goal(service, recent: true);
      addTearDown(controller.dispose);
      expect(
        await controller.attachSupplementLocation(CourtPoint(x: .4, y: .6)),
        isTrue,
      );
      await tester.pumpWidget(_app(controller));
      expect(controller.state.shotLocations, hasLength(1));
      expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);
      final undo = find.byKey(const Key('scoring-decision-undo-score'));
      await tester.tap(undo);
      await tester.tap(undo);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
      expect(controller.state.score.redScore, 10);
      expect(controller.state.shotLocations, isEmpty);
      expect(controller.state.decision, isNull);
      expect(find.byKey(const Key('scoring-decision-dock')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'continued target projection and later scoring omit obsolete goal hints',
    () async {
      final service = MatchCommandService(
        createTestDatabase(),
        now: () => _anchor,
      );
      final controller = await _goal(service);
      addTearDown(controller.dispose);
      controller.replaceCommittedProjection(
        await service.continueMatch(
          ContinueMatchCommand(matchId: 'goal-ui', occurredAt: _anchor),
        ),
      );
      expect(
        await controller.recordScoreCommitted(side: TeamSide.blue, points: 2),
        isTrue,
      );
      expect(controller.state.decision, isNull);
      expect(
        controller.state.ruleHints.where(
          (hint) =>
              hint.type == RuleHintType.targetReached ||
              hint.type == RuleHintType.matchPoint,
        ),
        isEmpty,
      );
      controller.cancelLocateLastUnlocatedShot();
      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(controller.state.decision, isNull);
      expect(
        await controller.recordFreeThrowCommitted(
          side: TeamSide.red,
          made: true,
        ),
        isTrue,
      );
      expect(controller.state.decision, isNull);
      expect(
        controller.state.ruleHints.where(
          (hint) =>
              hint.type == RuleHintType.targetReached ||
              hint.type == RuleHintType.matchPoint,
        ),
        isEmpty,
      );
    },
  );
}
