import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';

class DeviceAutomaticBackupStorage
    implements
        AutomaticBackupStorage,
        BackupRetentionStorage,
        AutomaticBackupReferencePolicy {
  DeviceAutomaticBackupStorage({
    AutomaticBackupStorage? fallback,
    bool? useAndroidSaf,
  }) : _fallback = fallback ?? const IoAutomaticBackupStorage(),
       _useAndroidSaf = useAndroidSaf ?? Platform.isAndroid;

  static const channelName = 'io.github.x1a0y4ngren.hooptrace/automatic_backup';
  static const _channel = MethodChannel(channelName);

  final AutomaticBackupStorage _fallback;
  final bool _useAndroidSaf;

  static Future<String> resolveBackgroundDatabasePath() async {
    final path = await _channel.invokeMethod<String>('backgroundDatabasePath');
    if (path == null || path.trim().isEmpty) {
      throw MissingPluginException('Background database path unavailable.');
    }
    return path;
  }

  @override
  bool acceptsDirectoryReference(String reference) {
    return !_useAndroidSaf || _isContentUri(reference);
  }

  Future<BackupDirectorySelection?> pickDirectory() async {
    if (!_useAndroidSaf) return null;
    final result = await _channel.invokeMapMethod<String, Object?>(
      'pickDirectory',
    );
    final reference = result?['reference'];
    final displayName = result?['displayName'];
    if (reference is! String || reference.trim().isEmpty) return null;
    final localizedFallback =
        PlatformDispatcher.instance.locale.languageCode == 'zh'
        ? '已授权文件夹'
        : 'Authorized folder';
    final nativeFallback = displayName == '已授权文件夹';
    return BackupDirectorySelection(
      reference: reference,
      displayName: displayName is String && displayName.trim().isNotEmpty
          ? (nativeFallback ? localizedFallback : displayName)
          : localizedFallback,
    );
  }

  @override
  Future<bool> directoryExists(String directory) async {
    if (!_useAndroidSaf) return _fallback.directoryExists(directory);
    if (!_isContentUri(directory)) return false;
    return await _channel.invokeMethod<bool>('directoryExists', {
          'directory': directory,
        }) ??
        false;
  }

  @override
  Future<String> write({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!_isWriteFileName(fileName)) {
      throw const AutomaticBackupWriteException();
    }
    if (!_useAndroidSaf) {
      return _fallback.write(
        directory: directory,
        fileName: fileName,
        bytes: bytes,
      );
    }
    if (!_isContentUri(directory)) {
      throw BackupDirectoryUnavailableException(directory);
    }
    final destination = await _channel.invokeMethod<String>('writeBackup', {
      'directory': directory,
      'fileName': fileName,
      'bytes': bytes,
    });
    if (destination == null || destination.isEmpty) {
      throw const AutomaticBackupWriteException();
    }
    return destination;
  }

  @override
  Future<List<String>> listFiles({required String directory}) async {
    if (!_useAndroidSaf) {
      final retentionStorage = _fallback is BackupRetentionStorage
          ? _fallback as BackupRetentionStorage
          : null;
      return retentionStorage?.listFiles(directory: directory) ?? const [];
    }
    _requireContentUri(directory);
    final result = await _channel.invokeMethod<Object?>('listBackupFiles', {
      'directory': directory,
    });
    if (result is! List) return const [];
    return result
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> deleteFile({
    required String directory,
    required String fileName,
  }) async {
    if (!_isAutomaticBackupFile(fileName)) return;
    if (!_useAndroidSaf) {
      final retentionStorage = _fallback is BackupRetentionStorage
          ? _fallback as BackupRetentionStorage
          : null;
      await retentionStorage?.deleteFile(
        directory: directory,
        fileName: fileName,
      );
      return;
    }
    _requireContentUri(directory);
    await _channel.invokeMethod<void>('deleteBackupFile', {
      'directory': directory,
      'fileName': fileName,
    });
  }

  void _requireContentUri(String directory) {
    if (!_isContentUri(directory)) {
      throw BackupDirectoryUnavailableException(directory);
    }
  }

  static bool _isContentUri(String value) => value.startsWith('content://');

  static bool _isAutomaticBackupFile(String fileName) {
    if (fileName.contains('/') || fileName.contains(r'\')) return false;
    return _automaticBackupPattern.hasMatch(fileName);
  }

  static bool _isWriteFileName(String fileName) {
    if (fileName.isEmpty || _controlCharacterPattern.hasMatch(fileName)) {
      return false;
    }
    return _writeFileNamePattern.hasMatch(fileName);
  }

  static final _controlCharacterPattern = RegExp(r'[\x00-\x1F\x7F]');
  static final _writeFileNamePattern = RegExp(
    r'^hoop(?:trace|ito)-(?:auto|backup|safety-backup)-[A-Za-z0-9][A-Za-z0-9._-]*\.json$',
  );
  static final _automaticBackupPattern = RegExp(
    r'^hoop(?:trace|ito)-auto-.+\.json$',
  );
}
