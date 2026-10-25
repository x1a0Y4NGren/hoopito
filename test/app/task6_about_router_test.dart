import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:hoopito/features/project/project_details_page.dart';
import 'package:hoopito/features/settings/settings_page.dart';

import '../test_helpers/test_database.dart';
import '../test_helpers/safety_backup_storage.dart';

void main() {
  testWidgets('/about is canonical and /project keeps the same About content', (
    tester,
  ) async {
    final database = createTestDatabase();
    final router = buildProviderAppRouter();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await database.close();
    });
    await tester.pumpWidget(_routerApp(database, router));
    await tester.pumpAndSettle();

    router.go('/about');
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDetailsPage), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Hoopito · 球豆'), findsOneWidget);

    router.go('/project');
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDetailsPage), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Hoopito · 球豆'), findsOneWidget);
  });

  testWidgets('optional recent-result failure never blocks Home', (
    tester,
  ) async {
    final database = createTestDatabase();
    final router = buildProviderAppRouter();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          activeMatchProvider.overrideWith(
            (ref) => Stream<MatchDetail?>.value(null),
          ),
          recentMatchSummariesProvider.overrideWith(
            (ref) => Stream.error(StateError('history failed')),
          ),
        ],
        child: _materialRouter(router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byKey(homeStartScoringKey), findsOneWidget);
    final home = find.byType(HomePage);
    final l10n = AppLocalizations.of(tester.element(home))!;
    expect(find.text(l10n.v2RecentMatches), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings About row opens canonical /about', (tester) async {
    final database = createTestDatabase();
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          exportCoordinatorProvider.overrideWith((ref) {
            final codec = ref.watch(backupCodecProvider);
            return ExportCoordinator(
              database,
              codec,
              gateway: ref.watch(exportGatewayProvider),
              automaticBackup: ref.watch(automaticBackupServiceProvider),
              safetyBackups: createTestSafetyBackupStore(codec),
            );
          }),
        ],
        child: _materialRouter(router),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/settings');
    await tester.pumpAndSettle();

    final about = find.byKey(const Key('settings-about-row'));
    await tester.scrollUntilVisible(
      about,
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(
      tester.element(about),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    final visibleAbout = about.hitTestable();
    expect(visibleAbout, findsOneWidget);
    await tester.tap(visibleAbout);
    await tester.pumpAndSettle();

    expect(find.byType(ProjectDetailsPage), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    final aboutRoute = GoRouterState.of(
      tester.element(find.byType(ProjectDetailsPage)),
    );
    expect(aboutRoute.matchedLocation, '/about');
    expect(aboutRoute.uri.path, '/about');
  });
}

Widget _routerApp(AppDatabase database, GoRouter router) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      activeMatchProvider.overrideWith(
        (ref) => Stream<MatchDetail?>.value(null),
      ),
      latestFinishedMatchProvider.overrideWithValue(
        const AsyncData<MatchDetail?>(null),
      ),
    ],
    child: _materialRouter(router),
  );
}

Widget _materialRouter(GoRouter router) => MaterialApp.router(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);
