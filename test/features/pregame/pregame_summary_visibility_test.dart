import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/entities/match_setup_preset.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';

const _eleven = RuleTemplate(
  id: 'race-eleven',
  name: '11 分比赛',
  scoreButtons: [1, 2, 3],
  targetScore: 11,
  winByTwo: true,
);
const _twentyOne = RuleTemplate(
  id: 'race-twenty-one',
  name: '21 分比赛',
  scoreButtons: [1, 2, 3],
  targetScore: 21,
);
const _preset = MatchSetupPreset(
  red: SetupParticipantPreset(nameSnapshot: 'River', playerId: 'river'),
  blue: SetupParticipantPreset(nameSnapshot: 'Jordan', playerId: 'jordan'),
  rules: _eleven,
);

void main() {
  for (final width in [413.0, 393.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'selected profiles keep rules and Start visible at ${width.toInt()}x734 and ${scale * 100}% text',
        (tester) async {
          final starts = <MatchSetup>[];
          await _pumpPregame(
            tester,
            width: width,
            scale: scale,
            onStart: starts.add,
          );

          final summary = find.byKey(const Key('pregame-rules-summary'));
          final l10n = AppLocalizations.of(
            tester.element(find.byType(PregamePage)),
          )!;
          expect(
            tester.widget<Text>(summary).data,
            contains(l10n.rulesTarget(11)),
          );
          _expectSummaryVisible(tester);
          final start = find.byKey(const Key('pregame-start-match'));
          final startBounds = tester.getRect(start);
          expect(startBounds.top, greaterThanOrEqualTo(24));
          expect(startBounds.bottom, lessThanOrEqualTo(734 - 28));
          expect(start.hitTestable(), findsOneWidget);
          await tester.tap(start);
          await tester.pumpAndSettle();
          expect(starts, hasLength(1));
          expect(starts.single.redPlayerProfileId, 'river');
          expect(starts.single.bluePlayerProfileId, 'jordan');

          final name = find.byKey(const Key('pregame-red-name'));
          await tester.ensureVisible(name);
          await tester.pumpAndSettle();
          await tester.enterText(name, 'River for this match');
          expect(
            tester.widget<TextField>(name).controller!.text,
            'River for this match',
          );
          await tester.ensureVisible(
            find.byKey(const Key('pregame-advanced-section')),
          );
          await tester.pumpAndSettle();
          final scroll = tester.state<ScrollableState>(_pageScrollable());
          expect(scroll.position.pixels, greaterThan(0));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'first-screen rules summary updates after a different rule is selected',
    (tester) async {
      await _pumpPregame(tester, width: 393, scale: 1);
      final dropdown = find.byKey(const Key('pregame-rule-template'));
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_twentyOne.name).last);
      await tester.pumpAndSettle();
      tester.state<ScrollableState>(_pageScrollable()).position.jumpTo(0);
      await tester.pump();

      final summary = find.byKey(const Key('pregame-rules-summary'));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PregamePage)),
      )!;
      final text = tester.widget<Text>(summary).data!;
      expect(text, contains(l10n.rulesTarget(21)));
      expect(text, isNot(contains(l10n.rulesTarget(11))));
      expect(find.text(text), findsOneWidget);
      _expectSummaryVisible(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _pageScrollable() => find
    .descendant(of: find.byType(PregamePage), matching: find.byType(Scrollable))
    .first;

void _expectSummaryVisible(WidgetTester tester) {
  final summary = find.byKey(const Key('pregame-rules-summary'));
  expect(summary, findsOneWidget);
  final summaryBounds = tester.getRect(summary);
  final viewport = tester.getRect(
    find
        .descendant(
          of: find.byType(PregamePage),
          matching: find.byType(SingleChildScrollView),
        )
        .first,
  );
  expect(summaryBounds.top, greaterThanOrEqualTo(viewport.top));
  expect(summaryBounds.bottom, lessThanOrEqualTo(viewport.bottom));
  expect(summaryBounds.top, greaterThanOrEqualTo(24));
  expect(
    summaryBounds.bottom,
    lessThanOrEqualTo(
      tester.getRect(find.byKey(const Key('pregame-start-match'))).top,
    ),
  );
  expect(summary.hitTestable(), findsOneWidget);
}

Future<void> _pumpPregame(
  WidgetTester tester, {
  required double width,
  required double scale,
  ValueChanged<MatchSetup>? onStart,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 734));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      theme: buildHoopitoTheme(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(top: 24, bottom: 28),
          viewPadding: const EdgeInsets.only(top: 24, bottom: 28),
        ),
        child: child!,
      ),
      home: PregamePage(
        initialPreset: _preset,
        templates: const [_eleven, _twentyOne],
        players: [
          Player(id: 'river', nickname: 'River', createdAt: DateTime.utc(2026)),
          Player(
            id: 'jordan',
            nickname: 'Jordan',
            createdAt: DateTime.utc(2026),
          ),
        ],
        onCreatePlayer: (nickname) async => Player(
          id: 'created',
          nickname: nickname,
          createdAt: DateTime.utc(2026),
        ),
        onStartMatch: onStart,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
