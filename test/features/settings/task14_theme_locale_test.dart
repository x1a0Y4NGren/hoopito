import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/core/settings/theme_preferences.dart';
import 'package:hoopito/features/settings/settings_controller.dart';
import 'package:hoopito/features/settings/settings_page.dart';

import '../../test_helpers/test_database.dart';
import '../../test_helpers/safety_backup_storage.dart';

void main() {
  testWidgets(
    'settings localizes in English and persists the three theme choices',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      });
      final codec = JsonBackupCodec(database, appVersion: '0.1.0+1');
      final automaticBackup = AutomaticBackupService(
        database,
        codec,
        storage: _Storage(),
      );
      final settings = SettingsController(
        exports: ExportCoordinator(
          database,
          codec,
          safetyBackups: createTestSafetyBackupStore(codec),
          gateway: _Gateway(),
          automaticBackup: automaticBackup,
        ),
        automaticBackup: automaticBackup,
        feedback: ScoringFeedbackService(
          ScoringFeedbackPreferencesRepository(database),
        ),
      );
      final theme = ThemePreferencesController(
        ThemePreferencesRepository(database),
      );
      addTearDown(settings.dispose);
      addTearDown(theme.dispose);
      await theme.load();

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
          theme: buildHoopitoTheme(),
          home: SettingsPage(controller: settings, themeController: theme),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<EditorialSectionRule>(find.byType(EditorialSectionRule))
            .map((rule) => rule.label),
        contains('Appearance'),
      );
      expect(find.text('外观'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('theme-preference-dropdown')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('theme-preference-dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('Dark'), findsWidgets);
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(theme.preference, AppThemePreference.dark);
    },
  );
}

class _Gateway implements ExportGateway {
  @override
  Future<ExportArtifact?> pickBackup({String? dialogTitle}) async => null;

  @override
  Future<BackupDirectorySelection?> pickDirectory({
    String? dialogTitle,
  }) async => null;

  @override
  Future<void> share(
    List<ExportArtifact> artifacts, {
    required String subject,
  }) async {}
}

class _Storage implements AutomaticBackupStorage {
  @override
  Future<bool> directoryExists(String path) async => false;

  @override
  Future<String> write({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  }) async => '$directory/$fileName';
}
