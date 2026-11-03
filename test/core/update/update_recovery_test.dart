import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/update/app_update.dart';
import '../../test_helpers/test_database.dart';
import 'app_update_test.dart' show FakePlatform, releaseJson;

void main() {
  test(
    'restored failed download permits explicit retry without a network check',
    () async {
      final db = createTestDatabase();
      final platform = RestoredPlatform();
      final controller = UpdateController(
        service: UpdateService(
          sourceReader: (_) => throw StateError('Unexpected network'),
        ),
        platform: platform,
        preferences: UpdatePreferencesRepository(db),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.availableRelease?.versionCode, 6);
      expect(controller.checkStatus, UpdateCheckStatus.updateAvailable);
      await controller.startDownload();
      expect(controller.download.phase, UpdateDownloadPhase.downloading);
    },
  );

  test(
    'query failure removes stale ready state and preserves retry release',
    () async {
      final db = createTestDatabase();
      final platform = RestoredPlatform(phase: UpdateDownloadPhase.ready);
      final controller = UpdateController(
        service: UpdateService(),
        platform: platform,
        preferences: UpdatePreferencesRepository(db),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.download.phase, UpdateDownloadPhase.ready);
      platform.failQuery = true;
      await controller.refreshDownload();
      expect(controller.download.phase, UpdateDownloadPhase.failed);
      expect(controller.download.release?.versionCode, 6);
      expect(controller.error, 'missing');
    },
  );

  test(
    'failed preference write is actionable and later writes still work',
    () async {
      final db = createTestDatabase();
      final controller = UpdateController(
        service: UpdateService(),
        platform: FakePlatform(),
        preferences: UpdatePreferencesRepository(db),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await db.customStatement(
        "CREATE TRIGGER reject_update_settings BEFORE INSERT ON app_settings BEGIN SELECT RAISE(ABORT, 'test storage error'); END",
      );
      await expectLater(
        controller.setAutoCheckEnabled(false),
        throwsA(anything),
      );
      expect(controller.autoCheckEnabled, isTrue);
      expect(controller.error, isNotNull);
      await db.customStatement('DROP TRIGGER reject_update_settings');
      await controller.setAutoCheckEnabled(false);
      expect(controller.autoCheckEnabled, isFalse);
      expect(await UpdatePreferencesRepository(db).load(), isFalse);
    },
  );
}

class RestoredPlatform extends FakePlatform {
  RestoredPlatform({this.phase = UpdateDownloadPhase.failed});
  final UpdateDownloadPhase phase;
  bool failQuery = false;
  @override
  Future<UpdateDownloadSnapshot> queryDownload() async {
    if (failQuery) throw const UpdateException('missing');
    return UpdateDownloadSnapshot(
      phase: phase,
      release: UpdateRelease.fromJson(
        jsonDecode(jsonEncode(releaseJson())) as Map<String, dynamic>,
      ),
    );
  }
}
