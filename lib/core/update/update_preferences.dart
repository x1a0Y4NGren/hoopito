import 'dart:convert';
import 'package:hoopito/core/data/app_database.dart';

const updatePreferencesKey = 'updates.preferences.v1';

class UpdatePreferencesRepository {
  UpdatePreferencesRepository(this.database);
  final AppDatabase database;

  // Deliberately uncached: replacement/import may replace the existing row.
  Future<bool> load() async {
    final row =
        await (database.select(database.appSettings)
              ..where((setting) => setting.key.equals(updatePreferencesKey)))
            .getSingleOrNull();
    if (row == null) return true;
    try {
      final value = jsonDecode(row.valueJson);
      if (value is Map &&
          value['version'] == 1 &&
          value['autoCheckEnabled'] is bool) {
        return value['autoCheckEnabled'] as bool;
      }
    } on FormatException {
      // Invalid/future settings use the same safe, user-visible default.
    }
    return true;
  }

  Future<void> save(bool enabled) => database
      .into(database.appSettings)
      .insertOnConflictUpdate(
        AppSetting(
          key: updatePreferencesKey,
          valueJson: jsonEncode({'version': 1, 'autoCheckEnabled': enabled}),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
}
