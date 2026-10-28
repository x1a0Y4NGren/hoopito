import 'dart:async';
import 'dart:convert';

import 'package:hoopito/core/update/app_update.dart';

final fakeUpdateManifest = <String, dynamic>{
  'schemaVersion': 1,
  'applicationId': 'io.github.x1a0y4ngren.hooptrace',
  'versionName': '2.0.2',
  'versionCode': 6,
  'minimumApi': 24,
  'releaseNotes': {'zh': '改进使用体验', 'en': 'Improve the experience'},
  'apk': {
    'bytes': 1024,
    'sha256': 'a' * 64,
    'url': 'https://hoopito.com/downloads/v2.0.2/Hoopito-v2.0.2-android.apk',
    'fallbackUrl':
        'https://github.com/x1a0Y4NGren/hoopito/releases/download/v2.0.2/Hoopito-v2.0.2-android.apk',
  },
};
final fakeUpdateJson = jsonEncode(fakeUpdateManifest);

class FakeUpdatePlatform implements UpdatePlatformGateway {
  @override
  bool supported = true;
  bool claimed = false;
  int claims = 0;
  int downloadStarts = 0;
  int installRequests = 0;
  int prepareRequests = 0;
  Completer<void>? preparing;
  bool failSettings = false;
  int settingsOpened = 0;
  UpdateInstallResult installResult = UpdateInstallResult.installerLaunched;
  UpdateDownloadSnapshot snapshot = const UpdateDownloadSnapshot();

  @override
  Future<InstalledAppInfo> getInstalledApp() async => const InstalledAppInfo(
    applicationId: 'io.github.x1a0y4ngren.hooptrace',
    versionName: '2.0.1',
    versionCode: 5,
    sdkInt: 36,
  );

  @override
  Future<bool> claimStartupCheck() async {
    claims++;
    if (claimed) return false;
    claimed = true;
    return true;
  }

  @override
  Future<UpdateDownloadSnapshot> startDownload(UpdateRelease release) async {
    downloadStarts++;
    snapshot = UpdateDownloadSnapshot(
      phase: UpdateDownloadPhase.ready,
      bytesReceived: release.apkBytes,
      bytesTotal: release.apkBytes,
      release: release,
    );
    return snapshot;
  }

  @override
  Future<UpdateDownloadSnapshot> queryDownload() async => snapshot;

  @override
  Future<void> cancelDownload() async {
    snapshot = const UpdateDownloadSnapshot();
  }

  @override
  Future<UpdateInstallResult> prepareInstall() async {
    prepareRequests++;
    await preparing?.future;
    return installResult == UpdateInstallResult.permissionRequired
        ? installResult
        : UpdateInstallResult.prepared;
  }

  @override
  Future<UpdateInstallResult> requestInstall() async {
    installRequests++;
    return installResult;
  }

  @override
  Future<void> openInstallSettings() async {
    settingsOpened++;
    if (failSettings) throw const UpdateException('unavailable');
  }
}
