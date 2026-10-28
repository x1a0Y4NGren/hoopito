import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'update_models.dart';
import 'update_platform.dart';
import 'update_preferences.dart';
import 'update_service.dart';

/// Auxiliary update state. It never mutates matches or automatically downloads.
/// The foreground host owns startup claims, prompting, polling and match guards.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required UpdateService service,
    required UpdatePlatformGateway platform,
    required UpdatePreferencesRepository preferences,
  }) : _service = service,
       _platform = platform,
       _preferences = preferences;
  final UpdateService _service;
  final UpdatePlatformGateway _platform;
  final UpdatePreferencesRepository _preferences;
  bool _disposed = false;
  bool _initialized = false;
  bool _autoCheckEnabled = true;
  InstalledAppInfo? _installedApp;
  UpdateRelease? _availableRelease;
  UpdateCheckStatus _checkStatus = UpdateCheckStatus.idle;
  UpdateDownloadSnapshot _download = const UpdateDownloadSnapshot();
  String? _error;
  Future<void>? _initializing;
  Future<void>? _checking;
  Future<void>? _starting;
  Future<void>? _refreshing;
  Future<UpdateInstallResult>? _installing;
  Future<void> _platformQueue = Future<void>.value();
  Future<void> _preferenceQueue = Future<void>.value();

  bool get supported => _platform.supported;
  bool get initialized => _initialized;
  bool get checking =>
      _checking != null || _checkStatus == UpdateCheckStatus.checking;
  bool get autoCheckEnabled => _autoCheckEnabled;
  InstalledAppInfo? get installedApp => _installedApp;
  UpdateRelease? get availableRelease => _availableRelease;
  UpdateCheckStatus get checkStatus => _checkStatus;
  UpdateDownloadSnapshot get download => _download;
  String? get error => _error;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  String _errorCode(Object error) => switch (error) {
    UpdateException(:final code) => code,
    PlatformException(:final code) => code,
    _ => 'unavailable',
  };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> initialize() {
    final loading = _initializing;
    if (loading != null) return loading;
    late final Future<void> operation;
    operation = _initialize().whenComplete(() {
      if (identical(_initializing, operation)) _initializing = null;
    });
    _initializing = operation;
    return operation;
  }

  Future<void> _initialize() async {
    if (!supported) {
      _initialized = true;
      _checkStatus = UpdateCheckStatus.unsupported;
      _publish();
      return;
    }
    try {
      _autoCheckEnabled = await _preferences.load();
      _installedApp ??= await _platform.getInstalledApp();
      await refreshDownload();
      _initialized = true;
    } on Object catch (error) {
      _error = _errorCode(error);
    }
    _publish();
  }

  Future<void> checkForUpdates() {
    final checking = _checking;
    if (checking != null) return checking;
    _checkStatus = supported
        ? UpdateCheckStatus.checking
        : UpdateCheckStatus.unsupported;
    _error = null;
    late final Future<void> operation;
    operation = _check().whenComplete(() {
      if (identical(_checking, operation)) _checking = null;
      _publish();
    });
    _checking = operation;
    _publish();
    return operation;
  }

  Future<void> _check() async {
    if (!supported) {
      _initialized = true;
      return;
    }
    try {
      if (!_initialized) await initialize();
      final installed = _installedApp;
      if (installed == null) throw const UpdateException('unavailable');
      final result = await _service.check(installed);
      _availableRelease = result.release;
      _checkStatus = result.status;
      _error = null;
    } on Object catch (error) {
      _availableRelease = null;
      _checkStatus = UpdateCheckStatus.failed;
      _error = _errorCode(error);
    }
  }

  Future<void> setAutoCheckEnabled(bool enabled) {
    final operation = _preferenceQueue.then((_) async {
      try {
        await _preferences.save(enabled);
        _autoCheckEnabled = enabled;
        _error = null;
      } on Object catch (error) {
        _error = _errorCode(error);
        _publish();
        rethrow;
      }
      _publish();
    });
    _preferenceQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final operation = _platformQueue.then((_) => action());
    _platformQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<void> startDownload() {
    if (_starting != null) return _starting!;
    late final Future<void> operation;
    operation =
        _serial(() async {
          final release = _availableRelease ?? _download.release;
          if (!supported || !_eligible(release)) return;
          try {
            _download = await _platform.startDownload(release!);
            _error = _download.error;
          } on Object catch (error) {
            _error = _errorCode(error);
            _download = UpdateDownloadSnapshot(
              phase: UpdateDownloadPhase.failed,
              release: release,
              error: _error,
            );
          }
          _publish();
        }).whenComplete(() {
          if (identical(_starting, operation)) _starting = null;
        });
    _starting = operation;
    return operation;
  }

  Future<void> refreshDownload() {
    if (_refreshing != null) return _refreshing!;
    late final Future<void> operation;
    operation =
        _serial(() async {
          if (!supported) return;
          try {
            _download = await _platform.queryDownload();
            _error = _download.error;
            final restored = _download.release;
            if (_availableRelease == null && _eligible(restored)) {
              _availableRelease = restored;
              if (_checkStatus != UpdateCheckStatus.checking) {
                _checkStatus = UpdateCheckStatus.updateAvailable;
              }
            }
          } on Object catch (error) {
            _error = _errorCode(error);
            _download = UpdateDownloadSnapshot(
              phase: UpdateDownloadPhase.failed,
              release: _download.release,
              error: _error,
            );
          }
          _publish();
        }).whenComplete(() {
          if (identical(_refreshing, operation)) _refreshing = null;
        });
    _refreshing = operation;
    return operation;
  }

  bool _eligible(UpdateRelease? release) {
    final installed = _installedApp;
    return release != null &&
        installed != null &&
        release.applicationId == installed.applicationId &&
        release.versionCode > installed.versionCode &&
        release.minimumApi <= installed.sdkInt;
  }

  Future<void> cancelDownload() => _serial(() async {
    if (!supported) return;
    try {
      await _platform.cancelDownload();
      _download = const UpdateDownloadSnapshot();
      _error = null;
    } on Object catch (error) {
      _error = _errorCode(error);
    }
    _publish();
  });

  Future<UpdateInstallResult> requestInstall({bool Function()? canInstallNow}) {
    if (_installing != null) return _installing!;
    late final Future<UpdateInstallResult> operation;
    operation =
        _serial(() async {
          if (!supported) return UpdateInstallResult.unavailable;
          try {
            // Preparation hashes/parses on a worker. The initiating foreground
            // route must recheck live safety after that asynchronous boundary.
            final prepared = await _platform.prepareInstall();
            final result = prepared == UpdateInstallResult.prepared
                ? (!_disposed && canInstallNow?.call() == true
                      ? await _platform.requestInstall()
                      : UpdateInstallResult.unavailable)
                : prepared;
            if (result == UpdateInstallResult.unavailable) {
              // Native preparation can invalidate a missing/tampered ready
              // candidate. Refresh directly inside this queue so Retry is
              // immediately available without waiting for another resume.
              _download = await _platform.queryDownload();
              _error = _download.error ?? 'unavailable';
            } else {
              _error = null;
            }
            _publish();
            return result;
          } on Object catch (error) {
            _error = _errorCode(error);
            _publish();
            return UpdateInstallResult.unavailable;
          }
        }).whenComplete(() {
          if (identical(_installing, operation)) _installing = null;
        });
    _installing = operation;
    return operation;
  }

  Future<void> openInstallSettings() async {
    if (!supported) return;
    try {
      await _platform.openInstallSettings();
    } on Object catch (error) {
      _error = _errorCode(error);
      _publish();
      rethrow;
    }
  }
}
