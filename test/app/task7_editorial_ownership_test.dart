import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/features/home/home_page.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Home renders inverse team identity from the $brightness contextual tokens',
      (tester) async {
        final theme = buildHoopitoTheme(brightness: brightness);
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
            theme: theme,
            home: HomePage(
              activeMatch: _activeMatch,
              onStartScoring: () {},
              onContinue: () {},
              onAbandon: () async {},
              onOpenHistory: () {},
              onOpenPlayers: () {},
              onOpenRules: () {},
              onOpenSettings: () {},
              onOpenProject: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(
          find.byKey(const Key('home-editorial-hero')),
        );
        final editorial = editorialThemeOf(context);
        final blueRule = tester.widget<Container>(
          find.byKey(const Key('home-blue-identity-rule')),
        );
        final redRule = tester.widget<Container>(
          find.byKey(const Key('home-red-identity-rule')),
        );

        expect(blueRule.color, editorial.inverseTeamBlue);
        expect(redRule.color, editorial.inverseTeamRed);
        expect(
          _contrast(blueRule.color!, editorial.inverseSurface),
          greaterThanOrEqualTo(3),
        );
        expect(
          _contrast(redRule.color!, editorial.inverseSurface),
          greaterThanOrEqualTo(3),
        );
      },
    );
  }

  test('body and title styles expose the bundled CJK fallback', () {
    final textTheme = buildHoopitoTheme().textTheme;
    for (final style in [
      textTheme.bodyMedium,
      textTheme.bodyLarge,
      textTheme.labelLarge,
      textTheme.titleLarge,
    ]) {
      expect(style?.fontFamilyFallback, contains('Noto Sans SC'));
    }
  });
}

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

final _activeMatch = MatchDetail(
  match: Match(
    id: 'inverse-team-colors',
    createdAt: DateTime.utc(2026, 8, 26),
    startedAt: DateTime.utc(2026, 8, 26),
    lifecycle: MatchLifecycle.active,
    redName: 'Red',
    blueName: 'Blue',
    ruleTemplateSnapshot: const RuleTemplate(
      id: 'free',
      name: 'Free',
      scoreButtons: [1, 2, 3],
    ),
  ),
  events: const [],
  shotLocations: const [],
  redScore: 11,
  blueScore: 7,
  redFouls: 0,
  blueFouls: 0,
  shotAttemptCount: 0,
  locatedShotCount: 0,
);
