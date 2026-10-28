import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/update/app_update.dart';

import '../../test_helpers/test_database.dart';

Map<String, dynamic> releaseJson({int code = 6, int minimumApi = 24}) => {
  'schemaVersion': 1,
  'applicationId': 'io.github.x1a0y4ngren.hooptrace',
  'versionName': '2.0.2',
  'versionCode': code,
  'minimumApi': minimumApi,
  'releaseNotes': {'zh': '修复计分', 'en': 'Fix scoring'},
  'apk': {
    'bytes': 100,
    'sha256': 'a' * 64,
    'url': 'https://hoopito.com/downloads/v2.0.2/Hoopito.apk',
    'fallbackUrl':
        'https://github.com/x1a0Y4NGren/hoopito/releases/download/v2.0.2/Hoopito.apk',
  },
};

const installed = InstalledAppInfo(
  applicationId: 'io.github.x1a0y4ngren.hooptrace',
  versionName: '2.0.1',
  versionCode: 5,
  sdkInt: 24,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('release validates identity, integrity, and official APK URLs', () {
    final release = UpdateRelease.fromJson(releaseJson());
    expect(release.notesFor('zh'), '修复计分');
    expect(release.notesFor('fr'), 'Fix scoring');
    expect(release.toJson(), releaseJson());
    for (final data in [
      {...releaseJson(), 'schemaVersion': 2},
      {...releaseJson(), 'applicationId': 'another.app'},
      {...releaseJson(), 'versionCode': 6.5},
      {
        ...releaseJson(),
        'apk': {...releaseJson()['apk'], 'sha256': 'not-a-hash'},
      },
      {
        ...releaseJson(),
        'apk': {...releaseJson()['apk'], 'bytes': 0},
      },
      {
        ...releaseJson(),
        'apk': {...releaseJson()['apk'], 'url': 'http://hoopito.com/app.apk'},
      },
      {
        ...releaseJson(),
        'apk': {
          ...releaseJson()['apk'],
          'fallbackUrl':
              'https://github.com/attacker/repo/releases/download/v1/a.apk',
        },
      },
    ]) {
      expect(() => UpdateRelease.fromJson(data), throwsFormatException);
    }
  });

  test(
    'valid primary is authoritative even when older than fallback',
    () async {
      final visited = <Uri>[];
      final service = UpdateService(
        sourceReader: (uri) async {
          visited.add(uri);
          return jsonEncode(releaseJson(code: visited.length == 1 ? 4 : 20));
        },
      );
      expect(
        (await service.check(installed)).status,
        UpdateCheckStatus.upToDate,
      );
      expect(visited, hasLength(1));
    },
  );

  test(
    'failed or malformed primary falls back and compares numeric code',
    () async {
      var visits = 0;
      final service = UpdateService(
        sourceReader: (_) async {
          if (++visits == 1) return '{}';
          return jsonEncode(releaseJson());
        },
      );
      final result = await service.check(installed);
      expect(result.status, UpdateCheckStatus.updateAvailable);
      expect(result.release?.versionCode, 6);
      expect(visits, 2);
    },
  );

  test('minimum API yields actionable incompatible result', () async {
    final service = UpdateService(
      sourceReader: (_) async => jsonEncode(releaseJson(minimumApi: 26)),
    );
    final result = await service.check(installed);
    expect(result.status, UpdateCheckStatus.incompatible);
    expect(result.release?.minimumApi, 26);
  });

  test('oversized metadata and exhausted sources fail safely', () async {
    final service = UpdateService(sourceReader: (_) async => ' ' * 65537);
    expect(() => service.check(installed), throwsA(isA<UpdateException>()));
  });

  test(
    'preferences default enabled, persist and reload replacement values',
    () async {
      final db = createTestDatabase();
      final repository = UpdatePreferencesRepository(db);
      expect(await repository.load(), isTrue);
      await repository.save(false);
      expect(await UpdatePreferencesRepository(db).load(), isFalse);
      await db.delete(db.appSettings).go();
      expect(await repository.load(), isTrue);
      await db
          .into(db.appSettings)
          .insert(
            AppSetting(
              key: 'updates.preferences.v1',
              valueJson: '{broken',
              updatedAt: DateTime.utc(2026),
            ),
          );
      expect(await repository.load(), isTrue);
    },
  );

  test(
    'controller coalesces checks and never downloads during a check',
    () async {
      final db = createTestDatabase();
      final pending = Completer<String>();
      var reads = 0;
      final platform = FakePlatform();
      final controller = UpdateController(
        service: UpdateService(
          sourceReader: (_) {
            reads++;
            return pending.future;
          },
        ),
        platform: platform,
        preferences: UpdatePreferencesRepository(db),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.checkStatus, UpdateCheckStatus.idle);
      expect(platform.claims, 0);
      final a = controller.checkForUpdates();
      final b = controller.checkForUpdates();
      expect(controller.checking, isTrue);
      pending.complete(jsonEncode(releaseJson()));
      await Future.wait([a, b]);
      expect(reads, 1);
      expect(controller.checkStatus, UpdateCheckStatus.updateAvailable);
      expect(platform.downloads, 0);
      await controller.startDownload();
      expect(controller.download.phase, UpdateDownloadPhase.downloading);
      expect(platform.downloads, 1);
    },
  );

  test('controller surfaces failures and recovers on retry', () async {
    final db = createTestDatabase();
    var fail = true;
    final platform = FakePlatform();
    final controller = UpdateController(
      service: UpdateService(
        sourceReader: (_) async {
          if (fail) throw Exception('offline');
          return jsonEncode(releaseJson());
        },
      ),
      platform: platform,
      preferences: UpdatePreferencesRepository(db),
    );
    addTearDown(controller.dispose);
    await controller.checkForUpdates();
    expect(controller.initialized, isTrue);
    expect(controller.checkStatus, UpdateCheckStatus.failed);
    expect(controller.error, isNotNull);
    fail = false;
    await controller.checkForUpdates();
    expect(controller.checkStatus, UpdateCheckStatus.updateAvailable);
    expect(controller.error, isNull);
    platform.failDownloads = true;
    await controller.startDownload();
    expect(controller.download.phase, UpdateDownloadPhase.failed);
    expect(controller.error, 'storage');
    await controller.cancelDownload();
    expect(controller.download.phase, UpdateDownloadPhase.idle);
  });

  test('unsupported platform never invokes native or network checks', () async {
    final db = createTestDatabase();
    final controller = UpdateController(
      service: UpdateService(
        sourceReader: (_) => throw StateError('network called'),
      ),
      platform: FakePlatform(supported: false),
      preferences: UpdatePreferencesRepository(db),
    );
    addTearDown(controller.dispose);
    await controller.checkForUpdates();
    expect(controller.checkStatus, UpdateCheckStatus.unsupported);
    expect(await controller.requestInstall(), UpdateInstallResult.unavailable);
  });

  test(
    'gateway decodes native snapshots and install permission result',
    () async {
      const channel = MethodChannel(
        'io.github.x1a0y4ngren.hooptrace/app_update',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return switch (call.method) {
              'getInstalledApp' => {
                'applicationId': installed.applicationId,
                'versionName': '2.0.1',
                'versionCode': 5,
                'sdkInt': 24,
              },
              'startDownload' => {
                'phase': 'ready',
                'bytesReceived': 100,
                'bytesTotal': 100,
                'release': call.arguments,
                'error': null,
                'usedFallback': true,
              },
              'requestInstall' => 'permissionRequired',
              'prepareInstall' => 'prepared',
              _ => true,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final gateway = DeviceUpdatePlatformGateway(supported: true);
      expect((await gateway.getInstalledApp()).versionCode, 5);
      final download = await gateway.startDownload(
        UpdateRelease.fromJson(releaseJson()),
      );
      expect(download.phase, UpdateDownloadPhase.ready);
      expect(download.usedFallback, isTrue);
      expect(download.release?.versionCode, 6);
      expect(await gateway.prepareInstall(), UpdateInstallResult.prepared);
      expect(
        await gateway.requestInstall(),
        UpdateInstallResult.permissionRequired,
      );
    },
  );
}

class FakePlatform implements UpdatePlatformGateway {
  FakePlatform({this.supported = true});
  @override
  final bool supported;
  int claims = 0;
  int downloads = 0;
  bool failDownloads = false;
  @override
  Future<InstalledAppInfo> getInstalledApp() async => installed;
  @override
  Future<bool> claimStartupCheck() async {
    claims++;
    return true;
  }

  @override
  Future<UpdateDownloadSnapshot> startDownload(UpdateRelease release) async {
    downloads++;
    if (failDownloads) throw const UpdateException('storage');
    return UpdateDownloadSnapshot(
      phase: UpdateDownloadPhase.downloading,
      release: release,
    );
  }

  @override
  Future<UpdateDownloadSnapshot> queryDownload() async =>
      const UpdateDownloadSnapshot();
  @override
  Future<void> cancelDownload() async {}
  @override
  Future<UpdateInstallResult> prepareInstall() async =>
      UpdateInstallResult.prepared;
  @override
  Future<UpdateInstallResult> requestInstall() async =>
      UpdateInstallResult.permissionRequired;
  @override
  Future<void> openInstallSettings() async {}
}
