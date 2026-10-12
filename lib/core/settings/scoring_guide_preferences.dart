import 'package:hoopito/core/data/app_database.dart';

class ScoringGuidePreferences {
  ScoringGuidePreferences(this.database);
  final AppDatabase database;
  static const key = 'scoring.guide.seen.v2';
  Future<bool> hasSeen() async {
    final row = await (database.select(
      database.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.valueJson == 'true';
  }

  Future<void> markSeen() => database
      .into(database.appSettings)
      .insertOnConflictUpdate(
        AppSetting(
          key: key,
          valueJson: 'true',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
}
