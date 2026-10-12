import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match.dart' as domain_match;
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';

import '../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);

  testWidgets('English pregame defaults are localized before first paint', (
    tester,
  ) async {
    await _setSurface(tester, const Size(800, 1000));
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
        home: const PregamePage(),
      ),
    );
    await tester.pumpAndSettle();

    final red = tester.widget<TextField>(
      find.byKey(const Key('pregame-red-name')),
    );
    final blue = tester.widget<TextField>(
      find.byKey(const Key('pregame-blue-name')),
    );
    expect(red.controller?.text, 'Red');
    expect(blue.controller?.text, 'Blue');
    expect(find.text('红方'), findsNothing);
    expect(find.text('蓝方'), findsNothing);
  });

  for (final locale in const [Locale('en'), Locale('zh')]) {
    testWidgets(
      'home meets tap-label-contrast guidelines at 200% in ${locale.languageCode}',
      (tester) async {
        await _setSurface(tester, const Size(390, 844));
        await tester.pumpWidget(
          _fixture(
            locale: locale,
            brightness: Brightness.light,
            textScaler: const TextScaler.linear(2),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester, meetsGuideline(androidTapTargetGuideline));
        expect(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(tester, meetsGuideline(textContrastGuideline));
        expect(tester.takeException(), isNull);
      },
    );
  }

  final goldenCases =
      <({Locale locale, Brightness brightness, Size size, String name})>[
        (
          locale: const Locale('en'),
          brightness: Brightness.light,
          size: const Size(390, 844),
          name: 'home_en_light_compact',
        ),
        (
          locale: const Locale('zh'),
          brightness: Brightness.light,
          size: const Size(390, 844),
          name: 'home_zh_light_compact',
        ),
        (
          locale: const Locale('en'),
          brightness: Brightness.dark,
          size: const Size(800, 600),
          name: 'home_en_dark_large',
        ),
        (
          locale: const Locale('zh'),
          brightness: Brightness.dark,
          size: const Size(800, 600),
          name: 'home_zh_dark_large',
        ),
      ];

  for (final goldenCase in goldenCases) {
    testWidgets('golden ${goldenCase.name}', (tester) async {
      await _setSurface(tester, goldenCase.size);
      await tester.pumpWidget(
        _fixture(locale: goldenCase.locale, brightness: goldenCase.brightness),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('task14-golden-root')),
        matchesGoldenFile(hoopitoGoldenFile(goldenCase.name)),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _fixture({
  required Locale locale,
  required Brightness brightness,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildHoopitoTheme(),
    darkTheme: buildHoopitoTheme(brightness: Brightness.dark),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: RepaintBoundary(
      key: const Key('task14-golden-root'),
      child: HomePage(
        showDirectory: false,
        activeMatch: _activeMatch,
        onStartScoring: _noop,
        onContinue: _noop,
        onAbandon: _noopAsync,
        onOpenHistory: _noop,
        onOpenPlayers: _noop,
        onOpenRules: _noop,
        onOpenSettings: _noop,
        onOpenProject: _noop,
      ),
    ),
  );
}

final _activeMatch = MatchDetail(
  match: domain_match.Match(
    id: 'task14-golden',
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
        id: 'task14-red',
        matchId: 'task14-golden',
        side: TeamSide.red,
        nameSnapshot: 'River',
      ),
      domain_match.MatchParticipant(
        id: 'task14-blue',
        matchId: 'task14-golden',
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

void _noop() {}

Future<void> _noopAsync() async {}
