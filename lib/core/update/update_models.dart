import 'package:flutter/foundation.dart';

const updateApplicationId = 'io.github.x1a0y4ngren.hooptrace';

class UpdateException implements Exception {
  const UpdateException(this.code);
  final String code;
  @override
  String toString() => 'UpdateException($code)';
}

enum UpdateCheckStatus {
  idle,
  checking,
  updateAvailable,
  upToDate,
  incompatible,
  failed,
  unsupported,
}

enum UpdateDownloadPhase {
  idle,
  queued,
  downloading,
  paused,
  verifying,
  ready,
  failed,
}

enum UpdateInstallResult {
  prepared,
  permissionRequired,
  installerLaunched,
  unavailable,
}

@immutable
class UpdateRelease {
  UpdateRelease({
    required this.applicationId,
    required this.versionName,
    required this.versionCode,
    required this.minimumApi,
    required Map<String, String> releaseNotes,
    required this.apkBytes,
    required this.apkSha256,
    required this.apkUrl,
    required this.apkFallbackUrl,
  }) : releaseNotes = Map.unmodifiable(releaseNotes);

  factory UpdateRelease.fromJson(Map<String, dynamic> json) {
    final apk = json['apk'];
    final notes = json['releaseNotes'];
    if (json['schemaVersion'] != 1 ||
        json['applicationId'] != updateApplicationId ||
        json['versionName'] is! String ||
        (json['versionName'] as String).trim().isEmpty ||
        !_positiveInt(json['versionCode']) ||
        !_positiveInt(json['minimumApi']) ||
        apk is! Map ||
        !_positiveInt(apk['bytes']) ||
        apk['sha256'] is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(apk['sha256'] as String) ||
        notes is! Map ||
        notes['zh'] is! String ||
        notes['en'] is! String) {
      throw const FormatException('Invalid update metadata');
    }
    final primary = _apkUri(apk['url'], github: false);
    final fallback = _apkUri(apk['fallbackUrl'], github: true);
    return UpdateRelease(
      applicationId: json['applicationId'] as String,
      versionName: json['versionName'] as String,
      versionCode: json['versionCode'] as int,
      minimumApi: json['minimumApi'] as int,
      releaseNotes: {'zh': notes['zh'] as String, 'en': notes['en'] as String},
      apkBytes: apk['bytes'] as int,
      apkSha256: (apk['sha256'] as String).toLowerCase(),
      apkUrl: primary,
      apkFallbackUrl: fallback,
    );
  }

  final String applicationId;
  final String versionName;
  final int versionCode;
  final int minimumApi;
  final Map<String, String> releaseNotes;
  final int apkBytes;
  final String apkSha256;
  final Uri apkUrl;
  final Uri apkFallbackUrl;

  String notesFor(String languageCode) =>
      releaseNotes[languageCode] ?? releaseNotes['en'] ?? '';
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'applicationId': applicationId,
    'versionName': versionName,
    'versionCode': versionCode,
    'minimumApi': minimumApi,
    'releaseNotes': releaseNotes,
    'apk': {
      'bytes': apkBytes,
      'sha256': apkSha256,
      'url': apkUrl.toString(),
      'fallbackUrl': apkFallbackUrl.toString(),
    },
  };

  static bool _positiveInt(dynamic value) => value is int && value > 0;
  static Uri _apkUri(dynamic value, {required bool github}) {
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery ||
        uri.port != 443 ||
        !uri.path.endsWith('.apk') ||
        (github
            ? uri.host != 'github.com' ||
                  !uri.path.startsWith(
                    '/x1a0Y4NGren/hoopito/releases/download/',
                  )
            : uri.host != 'hoopito.com' ||
                  !uri.path.startsWith('/downloads/'))) {
      throw const FormatException('Unofficial APK URL');
    }
    return uri;
  }
}

@immutable
class InstalledAppInfo {
  const InstalledAppInfo({
    required this.applicationId,
    required this.versionName,
    required this.versionCode,
    required this.sdkInt,
  });
  final String applicationId;
  final String versionName;
  final int versionCode;
  final int sdkInt;
}

@immutable
class UpdateDownloadSnapshot {
  const UpdateDownloadSnapshot({
    this.phase = UpdateDownloadPhase.idle,
    this.bytesReceived = 0,
    this.bytesTotal = 0,
    this.release,
    this.error,
    this.usedFallback = false,
  });
  final UpdateDownloadPhase phase;
  final int bytesReceived;
  final int bytesTotal;
  final UpdateRelease? release;
  final String? error;
  final bool usedFallback;

  factory UpdateDownloadSnapshot.fromJson(Map<String, dynamic> json) {
    final release = json['release'];
    return UpdateDownloadSnapshot(
      phase: UpdateDownloadPhase.values.byName(json['phase'] as String),
      bytesReceived: json['bytesReceived'] as int? ?? 0,
      bytesTotal: json['bytesTotal'] as int? ?? 0,
      release: release == null
          ? null
          : UpdateRelease.fromJson(Map<String, dynamic>.from(release as Map)),
      error: json['error'] as String?,
      usedFallback: json['usedFallback'] as bool? ?? false,
    );
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({required this.status, this.release});
  final UpdateCheckStatus status;
  final UpdateRelease? release;
}
