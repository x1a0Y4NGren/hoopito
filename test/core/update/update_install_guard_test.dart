import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/update/app_update.dart';

import '../../test_helpers/fake_update_platform.dart';
import '../../test_helpers/test_database.dart';

void main() {
  for (final guard in ['missing', 'blocked', 'allowed']) {
    test('install preparation requires a fresh $guard guard', () async {
      final db = createTestDatabase();
      final ready = Completer<void>();
      final platform = FakeUpdatePlatform()..preparing = ready;
      final controller = UpdateController(
        service: UpdateService(),
        platform: platform,
        preferences: UpdatePreferencesRepository(db),
      );
      var checks = 0;
      final operation = controller.requestInstall(
        canInstallNow: guard == 'missing'
            ? null
            : () {
                checks++;
                expect(ready.isCompleted, isTrue);
                return guard == 'allowed';
              },
      );
      await Future<void>.delayed(Duration.zero);
      expect(platform.prepareRequests, 1);
      expect(platform.installRequests, 0);
      expect(checks, 0);
      ready.complete();
      expect(
        await operation,
        guard == 'allowed'
            ? UpdateInstallResult.installerLaunched
            : UpdateInstallResult.unavailable,
      );
      expect(platform.installRequests, guard == 'allowed' ? 1 : 0);
      expect(checks, guard == 'missing' ? 0 : 1);
      controller.dispose();
      await db.close();
    });
  }

  test(
    'installation settings failure publishes and propagates the error',
    () async {
      final db = createTestDatabase();
      final controller = UpdateController(
        service: UpdateService(),
        platform: FakeUpdatePlatform()..failSettings = true,
        preferences: UpdatePreferencesRepository(db),
      );
      await expectLater(
        controller.openInstallSettings(),
        throwsA(isA<UpdateException>()),
      );
      expect(controller.error, 'unavailable');
      controller.dispose();
      await db.close();
    },
  );

  for (final failure in ['missing', 'verification']) {
    test(
      'failed preparation replaces ready snapshot with $failure retry state',
      () async {
        final db = createTestDatabase();
        final platform = _LostCandidatePlatform(failure);
        final controller = UpdateController(
          service: UpdateService(sourceReader: (_) async => fakeUpdateJson),
          platform: platform,
          preferences: UpdatePreferencesRepository(db),
        );
        await controller.initialize();
        await controller.checkForUpdates();
        await controller.startDownload();
        expect(controller.download.phase, UpdateDownloadPhase.ready);
        expect(
          await controller.requestInstall(canInstallNow: () => true),
          UpdateInstallResult.unavailable,
        );
        expect(controller.download.phase, UpdateDownloadPhase.failed);
        expect(controller.download.error, failure);
        expect(controller.error, failure);
        expect(platform.installRequests, 0);
        await controller.startDownload();
        expect(platform.downloadStarts, 2);
        controller.dispose();
        await db.close();
      },
    );
  }
}

class _LostCandidatePlatform extends FakeUpdatePlatform {
  _LostCandidatePlatform(this.failure);
  final String failure;
  @override
  Future<UpdateInstallResult> prepareInstall() async {
    snapshot = UpdateDownloadSnapshot(
      phase: UpdateDownloadPhase.failed,
      release: snapshot.release,
      error: failure,
    );
    return UpdateInstallResult.unavailable;
  }
}
