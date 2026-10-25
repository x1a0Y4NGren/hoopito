import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/clock/clock_engine.dart';
import 'package:hoopito/core/domain/entities/clock_state.dart';
import 'package:hoopito/core/domain/entities/match.dart' as domain_match;
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/home/home_page.dart';

void main() {
  testWidgets('a restored untimed match does not claim its clock is paused', (
    tester,
  ) async {
    final persistedClock = ClockEngine().project(
      state: ClockState(
        id: 'restored-untimed-clock',
        matchId: _activeMatch.match.id,
        mode: ClockMode.countUp,
        phase: ClockPhase.regulation,
        accumulatedSeconds: 0,
      ),
      now: DateTime.utc(2026, 10, 2),
    );
    for (final locale in const [Locale('en'), Locale('zh')]) {
      await _pumpHome(
        tester,
        locale: locale,
        activeMatch: _activeMatch.copyWith(clock: persistedClock),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byKey(homeResumeCardKey)),
      )!;
      expect(find.textContaining(l10n.homeClockNotConfigured), findsOneWidget);
      expect(find.textContaining(l10n.homeClockPaused), findsNothing);
      expect(find.byKey(homeResumeKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('empty home makes one editorial hero the start destination', (
    tester,
  ) async {
    final calls = <String>[];
    await _pumpHome(
      tester,
      locale: const Locale('en'),
      onOpenHistory: () => calls.add('history'),
      onOpenPlayers: () => calls.add('players'),
      onOpenRules: () => calls.add('rules'),
      onOpenSettings: () => calls.add('settings'),
      onOpenProject: () => calls.add('project'),
      onStartScoring: () => calls.add('start'),
    );

    expect(find.byType(EditorialScaffold), findsOneWidget);
    expect(find.text('HOOPITO'), findsOneWidget);
    expect(find.byKey(const Key('home-editorial-hero')), findsOneWidget);
    expect(find.byKey(homeStartScoringKey), findsOneWidget);
    expect(find.byKey(homeResumeKey), findsNothing);
    expect(find.byKey(homeProjectShortcutKey), findsNothing);
    for (final key in const [
      Key('home-history-shortcut'),
      Key('home-players-shortcut'),
      Key('home-rules-shortcut'),
      Key('home-settings-shortcut'),
    ]) {
      expect(find.byKey(key), findsOneWidget);
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
    }

    await tester.tap(find.byKey(homeStartScoringKey));
    for (final key in const [
      Key('home-history-shortcut'),
      Key('home-players-shortcut'),
      Key('home-rules-shortcut'),
      Key('home-settings-shortcut'),
    ]) {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
    }
    expect(calls, ['start', 'history', 'players', 'rules', 'settings']);
  });

  testWidgets('home directory is one linear localized semantic index', (
    tester,
  ) async {
    await _pumpHome(tester, locale: const Locale('zh'));
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;

    final labels = [
      l10n.replayHistory,
      l10n.playersTitle,
      l10n.rulesTitle,
      l10n.settings,
    ];
    for (var index = 0; index < labels.length; index++) {
      final key = Key(
        [
          'home-history-shortcut',
          'home-players-shortcut',
          'home-rules-shortcut',
          'home-settings-shortcut',
        ][index],
      );
      expect(find.text(labels[index]), findsWidgets);
      expect(tester.getSemantics(find.byKey(key)).label, labels[index]);
      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.text('0${index + 1}'),
        ),
        findsOneWidget,
      );
    }
    expect(_shortcutXs(tester).toSet(), hasLength(1));
    expect(find.text(l10n.projectDetails), findsNothing);
  });

  testWidgets(
    'active match offers Continue and confirmed Abandon without an invalid Start',
    (tester) async {
      var starts = 0;
      var resumes = 0;
      var abandons = 0;
      await _pumpHome(
        tester,
        activeMatch: _activeMatch,
        onStartScoring: () => starts++,
        onContinue: () => resumes++,
        onAbandon: () async => abandons++,
      );

      expect(find.byKey(const Key('home-editorial-hero')), findsOneWidget);
      expect(find.byKey(homeStartScoringKey), findsNothing);
      expect(find.text('River'), findsOneWidget);
      expect(find.text('Jordan'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(tester.widget(find.byKey(homeResumeKey)), isA<FilledButton>());

      await tester.tap(find.byKey(homeResumeKey));
      expect(resumes, 1);
      expect(starts, 0);

      await tester.ensureVisible(find.byKey(homeAbandonKey));
      await tester.tap(find.byKey(homeAbandonKey));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      expect(find.text(l10n.homeAbandonTitle), findsOneWidget);
      await tester.tap(find.text(l10n.homeConfirmAbandon));
      expect(abandons, 1);
    },
  );

  testWidgets('latest finished match is a compact tappable score strip', (
    tester,
  ) async {
    var historyOpens = 0;
    await _pumpHome(
      tester,
      latestFinishedMatch: _finishedMatch,
      onOpenHistory: () => historyOpens++,
    );

    expect(find.byKey(const Key('home-latest-result')), findsOneWidget);
    expect(find.byType(MatchScoreRow), findsOneWidget);
    expect(find.text('Comets'), findsOneWidget);
    expect(find.text('Owls'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-latest-result')));
    expect(historyOpens, 1);
  });

  testWidgets('home remains reachable at 200 percent text in light and dark', (
    tester,
  ) async {
    await _setSurface(tester, const Size(390, 844));
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await _pumpHome(
        tester,
        brightness: brightness,
        textScaler: const TextScaler.linear(2),
        activeMatch: _activeMatch,
      );
      expect(find.byKey(homeResumeKey), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('home-history-shortcut')),
      );
      expect(find.byKey(const Key('home-history-shortcut')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'inverse hero renders all text at accessible contrast with non-color team rules',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await _pumpHome(tester, brightness: brightness);
        final startContext = tester.element(
          find.byKey(const Key('home-editorial-hero')),
        );
        final startEditorial = editorialThemeOf(startContext);
        final startTitle = tester.widget<Text>(
          find
              .descendant(
                of: find.byKey(const Key('home-editorial-hero')),
                matching: find.text(
                  AppLocalizations.of(startContext)!.startScoring,
                ),
              )
              .first,
        );
        expect(
          _contrastRatio(
            startTitle.style!.color!,
            startEditorial.inverseSurface,
          ),
          greaterThanOrEqualTo(4.5),
          reason: 'the start title must remain readable on the inverse hero',
        );

        await _pumpHome(
          tester,
          brightness: brightness,
          activeMatch: _activeMatch,
        );
        final context = tester.element(
          find.byKey(const Key('home-editorial-hero')),
        );
        final editorial = editorialThemeOf(context);
        final l10n = AppLocalizations.of(context)!;
        for (final label in [
          l10n.homeActiveMatch.toUpperCase(),
          'River',
          'Jordan',
          '11',
          '9',
        ]) {
          final text = tester.widget<Text>(find.text(label));
          expect(
            _contrastRatio(text.style!.color!, editorial.inverseSurface),
            greaterThanOrEqualTo(4.5),
            reason: '$label must remain readable on the inverse hero',
          );
        }
        expect(
          find.byKey(const Key('home-blue-identity-rule')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('home-red-identity-rule')), findsOneWidget);
      }
    },
  );
}

Future<void> _pumpHome(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.light,
  MatchDetail? activeMatch,
  MatchDetail? latestFinishedMatch,
  VoidCallback? onOpenHistory,
  VoidCallback? onOpenPlayers,
  VoidCallback? onOpenRules,
  VoidCallback? onOpenSettings,
  VoidCallback? onOpenProject,
  VoidCallback? onStartScoring,
  VoidCallback? onContinue,
  Future<void> Function()? onAbandon,
}) async {
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: HomePage(
        activeMatch: activeMatch,
        latestFinishedMatch: latestFinishedMatch,
        onStartScoring: onStartScoring ?? () {},
        onContinue: onContinue ?? () {},
        onAbandon: onAbandon ?? () async {},
        onOpenHistory: onOpenHistory ?? () {},
        onOpenPlayers: onOpenPlayers ?? () {},
        onOpenRules: onOpenRules ?? () {},
        onOpenSettings: onOpenSettings ?? () {},
        onOpenProject: onOpenProject ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _activeMatch = MatchDetail(
  match: domain_match.Match(
    id: 'home-test-active',
    lifecycle: MatchLifecycle.active,
    createdAt: DateTime.utc(2026, 8, 24, 12),
    startedAt: DateTime.utc(2026, 8, 24, 12),
    ruleTemplateSnapshot: const RuleTemplate(
      id: 'free',
      name: 'Free scoring',
      scoreButtons: [1, 2, 3],
    ),
    participants: const [
      domain_match.MatchParticipant(
        id: 'home-test-red',
        matchId: 'home-test-active',
        side: TeamSide.red,
        nameSnapshot: 'River',
      ),
      domain_match.MatchParticipant(
        id: 'home-test-blue',
        matchId: 'home-test-active',
        side: TeamSide.blue,
        nameSnapshot: 'Jordan',
      ),
    ],
  ),
  events: const [],
  shotLocations: const [],
  redScore: 11,
  blueScore: 9,
  redFouls: 1,
  blueFouls: 2,
  shotAttemptCount: 0,
  locatedShotCount: 0,
);

final _finishedMatch = MatchDetail(
  match: domain_match.Match(
    id: 'home-test-finished',
    lifecycle: MatchLifecycle.finished,
    createdAt: DateTime.utc(2026, 8, 23, 12),
    startedAt: DateTime.utc(2026, 8, 23, 12),
    endedAt: DateTime.utc(2026, 8, 23, 13),
    ruleTemplateSnapshot: const RuleTemplate(
      id: 'free',
      name: 'Free scoring',
      scoreButtons: [1, 2, 3],
    ),
    participants: const [
      domain_match.MatchParticipant(
        id: 'home-test-finished-red',
        matchId: 'home-test-finished',
        side: TeamSide.red,
        nameSnapshot: 'Comets',
      ),
      domain_match.MatchParticipant(
        id: 'home-test-finished-blue',
        matchId: 'home-test-finished',
        side: TeamSide.blue,
        nameSnapshot: 'Owls',
      ),
    ],
  ),
  events: const [],
  shotLocations: const [],
  redScore: 21,
  blueScore: 18,
  redFouls: 0,
  blueFouls: 0,
  shotAttemptCount: 0,
  locatedShotCount: 0,
);

List<double> _shortcutXs(WidgetTester tester) {
  return [
    'home-history-shortcut',
    'home-players-shortcut',
    'home-rules-shortcut',
    'home-settings-shortcut',
  ].map((name) => tester.getCenter(find.byKey(Key(name))).dx).toList();
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final darker = identical(lighter, foreground) ? background : foreground;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
