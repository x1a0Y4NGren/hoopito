import 'dart:convert';

import 'package:hoopito/core/data/app_database.dart';

class PracticeProgress {
  const PracticeProgress({
    this.invitationHandled = false,
    this.practiceCompleted = false,
  });

  final bool invitationHandled;
  final bool practiceCompleted;
}

/// Lives in the real database; practice's disposable database never owns this.
class PracticePreferences {
  PracticePreferences(this.database);

  final AppDatabase database;
  static const key = 'onboarding.practice.v1';

  Future<PracticeProgress> load() async {
    final row = await (database.select(
      database.appSettings,
    )..where((setting) => setting.key.equals(key))).getSingleOrNull();
    if (row == null) return const PracticeProgress();
    final value = jsonDecode(row.valueJson);
    if (value is! Map<String, dynamic>) return const PracticeProgress();
    return PracticeProgress(
      invitationHandled: value['invitationHandled'] == true,
      practiceCompleted: value['practiceCompleted'] == true,
    );
  }

  Future<void> markInvitationHandled() => _mark(invitationHandled: true);

  Future<void> markPracticeCompleted() => _mark(practiceCompleted: true);

  // Serialize read/merge/write even across repository instances on the shared DB.
  Future<void> _mark({
    bool invitationHandled = false,
    bool practiceCompleted = false,
  }) => database.transaction(() async {
    final previous = await load();
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSetting(
            key: key,
            valueJson: jsonEncode({
              'invitationHandled':
                  previous.invitationHandled || invitationHandled,
              'practiceCompleted':
                  previous.practiceCompleted || practiceCompleted,
            }),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });
}
