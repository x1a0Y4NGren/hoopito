import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

void main() {
  final events = [
    for (var i = 0; i < 6; i++)
      MatchEvent.score(
        id: 'e$i',
        matchId: 'm',
        side: i.isEven ? TeamSide.red : TeamSide.blue,
        points: i + 1,
        occurredAt: DateTime.utc(2026).add(Duration(seconds: i)),
      ),
  ];
  final analytics = MatchAnalyticsCalculator().calculate(events);
  final detail = MatchDetail(
    match: Match(
      id: 'm',
      createdAt: DateTime.utc(2026),
      lifecycle: MatchLifecycle.finished,
      redName: 'Red',
      blueName: 'Blue',
      ruleTemplateSnapshot: const RuleTemplate(
        id: 'free',
        name: 'Free',
        scoreButtons: [1, 2, 3],
      ),
    ),
    events: events,
    shotLocations: const [],
    redScore: 9,
    blueScore: 12,
    redFouls: 0,
    blueFouls: 0,
    shotAttemptCount: 6,
    locatedShotCount: 0,
  );
  for (final language in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'result handles $language $brightness narrow landscape at 200%',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(620, 360));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final actions = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHoopitoTheme(brightness: brightness),
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: MatchSummaryPage(
                detail: detail,
                analytics: analytics,
                onBack: () {},
                onRematch: () => actions.add('rematch'),
                onReplay: () => actions.add('replay'),
                onShare: () => actions.add('share'),
                onCorrectCoverage: () {},
                onSavePlayer: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'summary-moment-',
                  ),
            ),
            findsNWidgets(2),
          );
          await tester.ensureVisible(find.byKey(const Key('summary-rematch')));
          await tester.tap(find.byKey(const Key('summary-rematch')));
          await tester.ensureVisible(find.byKey(const Key('summary-share')));
          await tester.tap(find.byKey(const Key('summary-share')));
          await tester.ensureVisible(find.byKey(const Key('summary-replay')));
          await tester.tap(find.byKey(const Key('summary-replay')));
          expect(actions, ['rematch', 'share', 'replay']);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
