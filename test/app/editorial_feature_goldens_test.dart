import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/entities/match.dart' as domain;
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

import '../support/golden_fonts.dart';

void main() {
  setUpAll(() async {
    await loadHoopitoGoldenFonts();
  });

  final features = <({String name, Size size, Widget Function() page})>[
    (name: 'summary', size: const Size(390, 844), page: _summaryPage),
    (
      name: 'pregame',
      size: const Size(390, 844),
      page: () => const PregamePage(),
    ),
    (
      name: 'pregame_target',
      size: const Size(390, 844),
      page: () => const PregamePage(),
    ),
    (
      name: 'scoring',
      size: const Size(731, 411),
      page: () => const ScoringPage(matchId: 'golden-scoring'),
    ),
    (
      name: 'replay',
      size: const Size(731, 411),
      page: () => ReplayPage(controller: _replayController()),
    ),
  ];

  for (final feature in features) {
    for (final locale in const [Locale('en'), Locale('zh')]) {
      for (final brightness in Brightness.values) {
        final mode = brightness == Brightness.light ? 'light' : 'dark';
        final name = '${feature.name}_${locale.languageCode}_$mode';
        testWidgets('editorial golden $name', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = feature.size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildHoopitoTheme(brightness: brightness),
              home: RepaintBoundary(
                key: const Key('editorial-feature-golden-root'),
                child: feature.page(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (feature.name == 'pregame_target') {
            await tester.ensureVisible(
              find.byKey(const Key('pregame-advanced')),
            );
            await tester.tap(find.byKey(const Key('pregame-advanced')));
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const Key('pregame-target-edit')),
            );
            await tester.tap(find.byKey(const Key('pregame-target-edit')));
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const Key('pregame-target-input')),
              '1000',
            );
            await tester.tap(find.byKey(const Key('pregame-target-confirm')));
            await tester.pumpAndSettle();
          }
          final renderedTheme = Theme.of(
            tester.element(
              find.byKey(const Key('editorial-feature-golden-root')),
            ),
          );
          expect(
            renderedTheme.textTheme.bodyMedium?.fontFamily,
            isNot('Noto Sans SC'),
            reason: 'Golden pages must retain the production body font.',
          );
          expect(
            renderedTheme.textTheme.bodyMedium?.fontFamilyFallback,
            contains('Noto Sans SC'),
            reason: 'Chinese must use the production fallback chain.',
          );
          await expectLater(
            feature.name == 'pregame_target'
                ? find.byType(MaterialApp)
                : find.byKey(const Key('editorial-feature-golden-root')),
            matchesGoldenFile(hoopitoGoldenFile(name)),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Widget _summaryPage() {
  final events = [
    for (var i = 0; i < 8; i++)
      MatchEvent.score(
        id: 'summary-e$i',
        matchId: 'summary-demo',
        side: i.isEven ? TeamSide.blue : TeamSide.red,
        points: i.isEven ? 2 : 3,
        occurredAt: DateTime.utc(2026, 10, 2, 10, i),
      ),
  ];
  final detail = MatchDetail(
    match: domain.Match(
      id: 'summary-demo',
      lifecycle: MatchLifecycle.finished,
      createdAt: DateTime.utc(2026, 10, 2, 10),
      endedAt: DateTime.utc(2026, 10, 2, 10, 8),
      redName: 'River',
      blueName: 'Jordan',
      ruleTemplateSnapshot: const RuleTemplate(
        id: 'free',
        name: 'Free',
        scoreButtons: [1, 2, 3],
      ),
      trackingCoverage: TrackingCoverage.scoresOnly,
    ),
    events: events,
    shotLocations: const [],
    redScore: 12,
    blueScore: 8,
    redFouls: 0,
    blueFouls: 0,
    shotAttemptCount: 8,
    locatedShotCount: 0,
  );
  return MatchSummaryPage(
    detail: detail,
    analytics: MatchAnalyticsCalculator().calculate(events),
    onBack: () {},
    onRematch: () {},
    onReplay: () {},
    onShare: () {},
    onCorrectCoverage: () {},
    onSavePlayer: (_) {},
  );
}

ReplayController _replayController() => ReplayController(
  data: ReplayMatchData(
    matchId: 'golden-replay',
    blueName: 'Blue',
    redName: 'Red',
    blueScore: 2,
    redScore: 3,
    duration: const Duration(minutes: 8, seconds: 24),
    events: [
      ReplayEventData(
        id: 'golden-event-1',
        kind: ReplayEventKind.score,
        rawKind: EventKind.fieldGoal,
        side: TeamSide.blue,
        points: 2,
        outcome: ShotOutcome.made,
        elapsed: const Duration(seconds: 18),
        occurredAt: DateTime.utc(2026, 8, 26, 12),
      ),
      ReplayEventData(
        id: 'golden-event-2',
        kind: ReplayEventKind.score,
        rawKind: EventKind.fieldGoal,
        side: TeamSide.red,
        points: 3,
        outcome: ShotOutcome.made,
        elapsed: const Duration(seconds: 41),
        occurredAt: DateTime.utc(2026, 8, 26, 12, 0, 23),
      ),
    ],
  ),
);
