import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:hoopito/features/settings/data_management_page.dart';
import 'package:hoopito/features/settings/settings_page.dart';

import '../test_helpers/test_database.dart';
import '../test_helpers/safety_backup_storage.dart';

void main() {
  testWidgets('direct data deep link has an explicit route back to settings', (
    tester,
  ) async {
    final database = createTestDatabase();
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    await tester.pumpWidget(_routerApp(database, router));
    router.go('/settings/data');
    await tester.pumpAndSettle();

    expect(find.byType(DataManagementPage), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets(
    'settings data row opens a routable page and returns to settings',
    (tester) async {
      final database = createTestDatabase();
      final router = buildProviderAppRouter();
      addTearDown(router.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      });
      await tester.pumpWidget(_routerApp(database, router));
      router.go('/settings');
      await tester.pumpAndSettle();

      final dataRow = find.byKey(const Key('settings-data-row'));
      await tester.scrollUntilVisible(
        dataRow,
        300,
        scrollable: find
            .descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(dataRow);
      await tester.tap(dataRow.hitTestable());
      await tester.pumpAndSettle();

      expect(find.byType(DataManagementPage), findsOneWidget);
      expect(
        GoRouterState.of(
          tester.element(find.byType(DataManagementPage)),
        ).matchedLocation,
        '/settings/data',
      );

      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
    },
  );
}

Widget _routerApp(AppDatabase database, GoRouter router) => ProviderScope(
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
  child: MaterialApp.router(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  ),
);
