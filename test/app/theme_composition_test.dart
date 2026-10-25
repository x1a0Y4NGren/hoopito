import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/entry/hoopito_entry_gate.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:hoopito/core/settings/language_preferences.dart';
import 'package:hoopito/core/settings/theme_preferences.dart';
import 'package:hoopito/features/home/home_page.dart';

import '../test_helpers/test_database.dart';
import '../test_helpers/safety_backup_storage.dart';

void main() {
  testWidgets('app theme mode is driven by the persisted preference', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });

    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    final container = ProviderScope.containerOf(context);
    final controller = container.read(themePreferencesControllerProvider);
    expect(controller.preference, AppThemePreference.system);

    await controller.setPreference(AppThemePreference.dark);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );

    await controller.setPreference(AppThemePreference.light);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
  });

  testWidgets('app defaults to Chinese when the system locale is English', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      tester.platformDispatcher.clearLocaleTestValue();
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    tester.platformDispatcher.localeTestValue = const Locale('en');

    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.locale, const Locale('zh'));
    expect(find.byKey(homeStartScoringKey), findsOneWidget);
    expect(materialApp.supportedLocales, contains(const Locale('en')));
    expect(materialApp.supportedLocales, contains(const Locale('zh')));
  });

  testWidgets('an explicit English choice persists across app restarts', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      tester.platformDispatcher.clearLocaleTestValue();
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    tester.platformDispatcher.localeTestValue = const Locale('en');

    await tester.pumpWidget(_memoryBackedApp(database));
    await tester.pumpAndSettle();
    final settingsShortcut = find.byKey(const Key('home-settings-shortcut'));
    await tester.ensureVisible(settingsShortcut);
    await tester.tap(settingsShortcut);
    await tester.pumpAndSettle();

    final languageDropdown = find.byKey(
      const Key('language-preference-dropdown'),
    );
    expect(languageDropdown, findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(languageDropdown),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(languageDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<EditorialSectionRule>(find.byType(EditorialSectionRule))
          .map((rule) => rule.label),
      contains('Appearance'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_memoryBackedApp(database));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.locale, const Locale('en'));
    expect(find.byKey(homeStartScoringKey), findsOneWidget);
  });

  testWidgets('a saved English choice gates localized startup content', (
    tester,
  ) async {
    final database = createTestDatabase();
    final repository = LanguagePreferencesRepository(database);
    await repository.save(AppLanguagePreference.english);
    final language = LanguagePreferencesController(repository);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          languagePreferencesControllerProvider.overrideWith((ref) => language),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.byKey(const Key('home-start-scoring')), findsNothing);
    expect(find.byType(HoopitoStartupPlaceholder), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await language.load();
    await tester.pumpAndSettle();
    expect(find.byKey(homeStartScoringKey), findsOneWidget);
  });

  testWidgets('unsupported system locale falls back before title generation', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      tester.platformDispatcher.clearLocaleTestValue();
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    tester.platformDispatcher.localeTestValue = const Locale('fr');

    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

Widget _memoryBackedApp(AppDatabase database) => ProviderScope(
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
  child: const HoopitoApp(showEntryAnimation: false),
);
