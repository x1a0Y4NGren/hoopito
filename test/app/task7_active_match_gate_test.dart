import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';

void main() {
  testWidgets(
    'active-match pregame gate is a flat editorial page with blue left and red right',
    (tester) async {
      tester.view.physicalSize = const Size(731, 411);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = buildProviderAppRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeMatchProvider.overrideWith(
              (ref) => Stream<MatchDetail?>.value(_activeMatch),
            ),
            latestFinishedMatchProvider.overrideWithValue(
              const AsyncData<MatchDetail?>(null),
            ),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildHoopitoTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/pregame');
      await tester.pumpAndSettle();

      expect(find.byType(EditorialScaffold), findsOneWidget);
      expect(find.byType(EditorialMasthead), findsOneWidget);
      expect(find.byType(EditorialSectionRule), findsWidgets);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(AppBar), findsNothing);

      final blue = find.byKey(const Key('active-gate-blue-team'));
      final red = find.byKey(const Key('active-gate-red-team'));
      expect(blue, findsOneWidget);
      expect(red, findsOneWidget);
      expect(tester.getCenter(blue).dx, lessThan(tester.getCenter(red).dx));
      final editorial = editorialThemeOf(tester.element(blue));
      final blueColors = tester
          .widgetList<Container>(
            find.descendant(of: blue, matching: find.byType(Container)),
          )
          .map((container) => container.color);
      final redColors = tester
          .widgetList<Container>(
            find.descendant(of: red, matching: find.byType(Container)),
          )
          .map((container) => container.color);
      expect(blueColors, contains(editorial.teamBlue));
      expect(redColors, contains(editorial.teamRed));
      expect(
        find.descendant(of: blue, matching: find.text('Blue')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: blue, matching: find.text('7')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: red, matching: find.text('Red')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: red, matching: find.text('11')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

final _activeMatch = MatchDetail(
  match: Match(
    id: 'active-gate',
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
