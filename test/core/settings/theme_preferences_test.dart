import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/settings/theme_preferences.dart';

import '../../test_helpers/test_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
  });

  tearDown(() => database.close());

  test(
    'theme preference defaults to system and survives a new controller',
    () async {
      final first = ThemePreferencesController(
        ThemePreferencesRepository(database),
      );
      addTearDown(first.dispose);

      await first.load();
      expect(first.preference, AppThemePreference.system);

      await first.setPreference(AppThemePreference.dark);
      expect(first.preference, AppThemePreference.dark);

      final second = ThemePreferencesController(
        ThemePreferencesRepository(database),
      );
      addTearDown(second.dispose);
      await second.load();

      expect(second.preference, AppThemePreference.dark);
      expect(second.themeMode, ThemeMode.dark);
    },
  );

  test(
    'invalid or future values fall back to system without throwing',
    () async {
      await database
          .into(database.appSettings)
          .insert(
            AppSetting(
              key: themePreferencesKey,
              valueJson: '{"version":99,"preference":"neon"}',
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final controller = ThemePreferencesController(
        ThemePreferencesRepository(database),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.preference, AppThemePreference.system);
      expect(controller.themeMode, ThemeMode.system);
    },
  );
}
