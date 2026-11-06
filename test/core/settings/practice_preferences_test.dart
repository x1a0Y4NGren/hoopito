import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/settings/practice_preferences.dart';
import 'package:hoopito/core/settings/scoring_guide_preferences.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('legacy guide flag does not consume the new invitation', () async {
    final db = createTestDatabase();
    await ScoringGuidePreferences(db).markSeen();
    final state = await PracticePreferences(db).load();
    expect(state.invitationHandled, isFalse);
    expect(state.practiceCompleted, isFalse);
    expect(await ScoringGuidePreferences(db).hasSeen(), isTrue);
  });

  test(
    'invitation dismissal survives repository recreation without completion',
    () async {
      final db = createTestDatabase();
      await PracticePreferences(db).markInvitationHandled();
      final state = await PracticePreferences(db).load();
      expect(state.invitationHandled, isTrue);
      expect(state.practiceCompleted, isFalse);
    },
  );

  test(
    'concurrent writes from separate instances preserve both flags',
    () async {
      final db = createTestDatabase();
      await Future.wait([
        PracticePreferences(db).markInvitationHandled(),
        PracticePreferences(db).markPracticeCompleted(),
      ]);
      final state = await PracticePreferences(db).load();
      expect(state.invitationHandled, isTrue);
      expect(state.practiceCompleted, isTrue);
      await PracticePreferences(db).markInvitationHandled();
      expect((await PracticePreferences(db).load()).practiceCompleted, isTrue);
    },
  );
}
