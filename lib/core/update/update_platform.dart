import 'dart:io';
import 'package:flutter/services.dart';
import 'update_models.dart';

abstract interface class UpdatePlatformGateway {
  bool get supported;
  Future<InstalledAppInfo> getInstalledApp();
  Future<bool> claimStartupCheck();
  Future<UpdateDownloadSnapshot> startDownload(UpdateRelease release);
  Future<UpdateDownloadSnapshot> queryDownload();
  Future<void> cancelDownload();
  Future<UpdateInstallResult> prepareInstall();
  Future<UpdateInstallResult> requestInstall();
  Future<void> openInstallSettings();
}

class DeviceUpdatePlatformGateway implements UpdatePlatformGateway {
  DeviceUpdatePlatformGateway({bool? supported, MethodChannel? channel})
    : supported = supported ?? Platform.isAndroid,
      _channel =
          channel ??
          const MethodChannel('io.github.x1a0y4ngren.hooptrace/app_update');
  @override
  final bool supported;
  final MethodChannel _channel;

  Future<Map<String, dynamic>> _map(String method, [dynamic arguments]) async {
    final value = await _channel.invokeMethod<Object?>(method, arguments);
    if (value is! Map) throw const UpdateException('unavailable');
    return Map<String, dynamic>.from(value);
  }

  @override
  Future<InstalledAppInfo> getInstalledApp() async {
    final data = await _map('getInstalledApp');
    return InstalledAppInfo(
      applicationId: data['applicationId'] as String,
      versionName: data['versionName'] as String,
      versionCode: data['versionCode'] as int,
      sdkInt: data['sdkInt'] as int,
    );
  }

  @override
  Future<bool> claimStartupCheck() async =>
      await _channel.invokeMethod<bool>('claimStartupCheck') ?? false;
  @override
  Future<UpdateDownloadSnapshot> startDownload(UpdateRelease release) async =>
      UpdateDownloadSnapshot.fromJson(
        await _map('startDownload', release.toJson()),
      );
  @override
  Future<UpdateDownloadSnapshot> queryDownload() async =>
      UpdateDownloadSnapshot.fromJson(await _map('queryDownload'));
  @override
  Future<void> cancelDownload() =>
      _channel.invokeMethod<void>('cancelDownload');
  @override
  Future<UpdateInstallResult> prepareInstall() async =>
      switch (await _channel.invokeMethod<String>('prepareInstall')) {
        'prepared' => UpdateInstallResult.prepared,
        'permissionRequired' => UpdateInstallResult.permissionRequired,
        _ => UpdateInstallResult.unavailable,
      };
  @override
  Future<UpdateInstallResult> requestInstall() async =>
      switch (await _channel.invokeMethod<String>('requestInstall')) {
        'permissionRequired' => UpdateInstallResult.permissionRequired,
        'installerLaunched' => UpdateInstallResult.installerLaunched,
        _ => UpdateInstallResult.unavailable,
      };
  @override
  Future<void> openInstallSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');
}
