import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/backup_retention.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/export/automatic_backup_scheduler.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

export 'backup_retention.dart';

sealed class AutomaticBackupException implements Exception {
  const AutomaticBackupException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class BackupDirectoryNotConfiguredException extends AutomaticBackupException {
  const BackupDirectoryNotConfiguredException()
    : super('Choose a backup directory before enabling automatic backup.');
}

class BackupDirectoryUnavailableException extends AutomaticBackupException {
  const BackupDirectoryUnavailableException(String directory)
    : super('The selected backup directory is unavailable: $directory');
}

class AutomaticBackupWriteException extends AutomaticBackupException {
  const AutomaticBackupWriteException()
    : super('The backup could not be written to the selected directory.');
}

class BackupDirectorySelection {
  const BackupDirectorySelection({
    required this.reference,
    required this.displayName,
  });

  final String reference;
  final String displayName;
}

class AutomaticBackupState {
  const AutomaticBackupState({
    required this.enabled,
    this.dirty = false,
    this.dirtyRevision = 0,
    this.dirtySince,
    this.retentionLimit = 10,
    this.directory,
    this.directoryLabel,
    this.lastBackupAt,
    this.lastBackupPath,
  });

  final bool enabled;
  final bool dirty;
  final int dirtyRevision;
  final DateTime? dirtySince;
  final int retentionLimit;
  final String? directory;
  final String? directoryLabel;
  final DateTime? lastBackupAt;
  final String? lastBackupPath;

  bool get isConfigured => directory != null;
}

abstract interface class AutomaticBackupStorage {
  Future<bool> directoryExists(String path);

  Future<String> write({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  });
}

abstract interface class AutomaticBackupReferencePolicy {
  bool acceptsDirectoryReference(String reference);
}

class IoAutomaticBackupStorage
    implements AutomaticBackupStorage, BackupRetentionStorage {
  const IoAutomaticBackupStorage();

  @override
  Future<bool> directoryExists(String path) => Directory(path).exists();

  @override
  Future<String> write({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final extension = path.extension(fileName);
    final baseName = path.basenameWithoutExtension(fileName);
    var destination = path.join(directory, fileName);
    var suffix = 1;
    while (await File(destination).exists()) {
      destination = path.join(directory, '$baseName-$suffix$extension');
      suffix++;
    }
    final temporary = File('$destination.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(destination);
    return destination;
  }

  @override
  Future<List<String>> listFiles({required String directory}) async {
    final entries = await Directory(
      directory,
    ).list(followLinks: false).toList();
    return [
      for (final entry in entries)
        if (entry is File) path.basename(entry.path),
    ];
  }

  @override
  Future<void> deleteFile({
    required String directory,
    required String fileName,
  }) async {
    if (path.basename(fileName) != fileName ||
        path.isAbsolute(fileName) ||
        !_automaticFilePattern.hasMatch(fileName)) {
      return;
    }
    await File(path.join(directory, fileName)).delete();
  }

  static final _automaticFilePattern = RegExp(
    r'^hoop(?:trace|ito)-auto-.+\.json$',
  );
}

class AutomaticBackupService {
  AutomaticBackupService(
    this.database,
    this.codec, {
    AutomaticBackupStorage? storage,
    AutomaticBackupScheduler? scheduler,
    DateTime Function()? now,
  }) : storage = storage ?? const IoAutomaticBackupStorage(),
       scheduler = scheduler ?? const NoopAutomaticBackupScheduler(),
       now = now ?? DateTime.now;

  static const _enabledKey = 'backup.automatic.enabled';
  static const _directoryKey = 'backup.automatic.directory';
  static const _directoryLabelKey = 'backup.automatic.directoryLabel';
  static const _lastBackupAtKey = 'backup.automatic.lastBackupAt';
  static const _lastBackupPathKey = 'backup.automatic.lastBackupPath';
  static const _dirtyKey = 'backup.automatic.dirty';
  static const _dirtyRevisionKey = 'backup.automatic.dirtyRevision';
  static const _dirtySinceKey = 'backup.automatic.dirtySince';
  static const _retentionLimitKey = 'backup.automatic.retentionLimit';
  static const defaultRetentionLimit = 10;
  static const minRetentionLimit = 1;
  static const maxRetentionLimit = 50;
  static const dueInterval = Duration(hours: 24);
  static const _runLeaseDuration = Duration(minutes: 30);
  static const _runLeaseWait = Duration(seconds: 60);
  static const _runLeasePollInterval = Duration(milliseconds: 50);
  static const _keys = {
    _enabledKey,
    _directoryKey,
    _directoryLabelKey,
    _lastBackupAtKey,
    _lastBackupPathKey,
    _dirtyKey,
    _dirtyRevisionKey,
    _dirtySinceKey,
    _retentionLimitKey,
  };

  final AppDatabase database;
  final JsonBackupCodec codec;
  final AutomaticBackupStorage storage;
  final AutomaticBackupScheduler scheduler;
  final DateTime Function() now;
  Future<_BackupRun>? _runInFlight;

  Future<bool> isEnabled() async => (await loadState()).enabled;

  Future<AutomaticBackupState> loadState() async {
    await database.ensureBackupDirtyTriggers();
    final query = database.select(database.appSettings)
      ..where((setting) => setting.key.isIn(_keys));
    final settings = {
      for (final row in await query.get()) row.key: jsonDecode(row.valueJson),
    };
    final rawDirectory = settings[_directoryKey];
    final rawDirectoryLabel = settings[_directoryLabelKey];
    var directory = rawDirectory is String && rawDirectory.trim().isNotEmpty
        ? rawDirectory
        : null;
    var directoryLabel =
        rawDirectoryLabel is String && rawDirectoryLabel.trim().isNotEmpty
        ? rawDirectoryLabel
        : null;
    var enabled = settings[_enabledKey] == true;
    var dirty = settings[_dirtyKey] == true;
    var dirtyRevision = _nonNegativeInt(settings[_dirtyRevisionKey]);
    var dirtySince = _parseUtcDateTime(settings[_dirtySinceKey]);
    if (dirty && dirtySince == null) {
      // Older trigger-created dirty states did not persist an anchor. Capture
      // the first observation so the 24-hour interval is stable thereafter.
      await database.transaction(() async {
        final latest = await _readDirtyMetadata();
        dirty = latest.dirty;
        dirtyRevision = latest.revision;
        dirtySince = latest.dirtySince;
        if (dirty && dirtySince == null) {
          dirtySince = now().toUtc();
          await _writeSetting(_dirtySinceKey, dirtySince!.toIso8601String());
          final afterWrite = await _readDirtyMetadata();
          dirty = afterWrite.dirty;
          dirtyRevision = afterWrite.revision;
          dirtySince = afterWrite.dirtySince;
        }
      });
    }
    final retentionLimit = _clampRetentionLimit(settings[_retentionLimitKey]);
    final referencePolicy = storage is AutomaticBackupReferencePolicy
        ? storage as AutomaticBackupReferencePolicy
        : null;
    if (directory != null &&
        referencePolicy != null &&
        !referencePolicy.acceptsDirectoryReference(directory)) {
      await (database.delete(database.appSettings)..where(
            (setting) => setting.key.isIn({
              _enabledKey,
              _directoryKey,
              _directoryLabelKey,
            }),
          ))
          .go();
      enabled = false;
      directory = null;
      directoryLabel = null;
    }
    final rawLastBackupAt = settings[_lastBackupAtKey];
    final rawLastBackupPath = settings[_lastBackupPathKey];
    return AutomaticBackupState(
      enabled: enabled,
      dirty: dirty,
      dirtyRevision: dirtyRevision,
      dirtySince: dirtySince,
      retentionLimit: retentionLimit,
      directory: directory,
      directoryLabel: directoryLabel,
      lastBackupAt: rawLastBackupAt is String
          ? DateTime.tryParse(rawLastBackupAt)?.toUtc()
          : null,
      lastBackupPath: rawLastBackupPath is String ? rawLastBackupPath : null,
    );
  }

  Future<void> configureDirectory(
    String directory, {
    String? displayName,
  }) async {
    final normalized = directory.trim();
    if (normalized.isEmpty) {
      throw const BackupDirectoryNotConfiguredException();
    }
    if (!await storage.directoryExists(normalized)) {
      throw BackupDirectoryUnavailableException(normalized);
    }
    final normalizedLabel = displayName?.trim();
    await database.transaction(() async {
      await _writeSetting(_directoryKey, normalized);
      await _writeSetting(
        _directoryLabelKey,
        normalizedLabel == null || normalizedLabel.isEmpty
            ? normalized
            : normalizedLabel,
      );
    });
    final state = await loadState();
    if (state.enabled && state.isConfigured) await _ensureScheduled();
  }

  Future<void> enable() async {
    final state = await loadState();
    final directory = state.directory;
    if (directory == null) {
      throw const BackupDirectoryNotConfiguredException();
    }
    if (!await storage.directoryExists(directory)) {
      throw BackupDirectoryUnavailableException(directory);
    }
    await database.ensureBackupDirtyTriggers();
    // Publish enabled and a dirty baseline atomically. Domain writes cannot
    // slip between those two states, and writes during the baseline export
    // advance the revision so the successful export will leave them dirty.
    await database.transaction(() async {
      await _markDirtyMetadata();
      await _writeSetting(_enabledKey, true);
    });
    try {
      await runNow();
      await _ensureScheduled();
    } on Object {
      // A failed baseline must not leave the feature presented as enabled.
      // Dirty metadata is retained so a later enable cannot forget changes
      // that landed while the failed export was in progress.
      await disable();
      rethrow;
    }
  }

  Future<void> disable() async {
    await _writeSetting(_enabledKey, false);
    await _cancelScheduled();
  }

  Future<void> markDirty() async {
    await database.ensureBackupDirtyTriggers();
    await database.transaction(_markDirtyMetadata);
    final state = await loadState();
    if (state.enabled && state.isConfigured) await _ensureScheduled();
  }

  Future<void> _markDirtyMetadata() async {
    final revision = await _readDirtyRevision();
    final wasDirty = await _readDirty();
    if (!wasDirty || await _readDirtySince() == null) {
      await _writeSetting(_dirtySinceKey, now().toUtc().toIso8601String());
    }
    await _writeSetting(_dirtyRevisionKey, revision + 1);
    await _writeSetting(_dirtyKey, true);
  }

  Future<void> setRetentionLimit(int value) =>
      _writeSetting(_retentionLimitKey, _clampRetentionLimit(value));

  Future<String?> runIfDue() async {
    final state = await loadState();
    if (!state.enabled || !state.isConfigured) {
      if (!state.enabled) await _cancelScheduled();
      return null;
    }
    await _ensureScheduled();
    if (!state.dirty) return null;
    final dirtySince = state.dirtySince;
    if (dirtySince == null ||
        now().toUtc().isBefore(dirtySince.add(dueInterval))) {
      return null;
    }
    return _runShared(filePrefix: 'hoopito-auto');
  }

  Future<String> runNow() => _runShared(filePrefix: 'hoopito-backup');

  /// Match completion is a durable checkpoint and is backed up immediately;
  /// the 24-hour delay applies only to other outstanding data changes.
  Future<String?> runAfterMatchFinish() async {
    if (!await isEnabled()) return null;
    await markDirty();
    final inFlight = _runInFlight;
    if (inFlight == null) return _runShared(filePrefix: 'hoopito-auto');

    final completed = await inFlight;
    if (identical(_runInFlight, inFlight)) _runInFlight = null;
    final state = await loadState();
    if (state.dirtyRevision != completed.dirtyRevision) {
      return _runShared(filePrefix: 'hoopito-auto');
    }
    return completed.destination;
  }

  Future<String> _runShared({required String filePrefix}) async {
    final inFlight = _runInFlight;
    if (inFlight != null) return (await inFlight).destination;
    final future = _runNowInternal(filePrefix: filePrefix);
    _runInFlight = future;
    unawaited(
      future.then<void>(
        (_) {
          if (identical(_runInFlight, future)) _runInFlight = null;
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_runInFlight, future)) _runInFlight = null;
        },
      ),
    );
    return (await future).destination;
  }

  Future<_BackupRun> _runNowInternal({required String filePrefix}) async {
    final lease = await _acquireRunLease();
    try {
      return await _runNowWithLease(
        filePrefix: filePrefix,
        contended: lease.contended,
      );
    } finally {
      await _releaseRunLease(lease.token);
    }
  }

  Future<_BackupRun> _runNowWithLease({
    required String filePrefix,
    required bool contended,
  }) async {
    final state = await loadState();
    if (contended && !state.dirty && state.lastBackupPath != null) {
      return _BackupRun(
        destination: state.lastBackupPath!,
        dirtyRevision: state.dirtyRevision,
      );
    }
    final directory = state.directory;
    if (directory == null) {
      throw const BackupDirectoryNotConfiguredException();
    }
    if (!await storage.directoryExists(directory)) {
      throw BackupDirectoryUnavailableException(directory);
    }
    final timestamp = now().toUtc();
    final payload = await codec.export();
    late final String destination;
    try {
      destination = await storage.write(
        directory: directory,
        fileName: '$filePrefix-${_fileTimestamp(timestamp)}.json',
        bytes: Uint8List.fromList(utf8.encode(payload)),
      );
    } on AutomaticBackupException {
      rethrow;
    } on Object {
      throw const AutomaticBackupWriteException();
    }
    await database.transaction(() async {
      await _writeSetting(_lastBackupAtKey, timestamp.toIso8601String());
      await _writeSetting(_lastBackupPathKey, destination);
      if (await _readDirtyRevision() == state.dirtyRevision) {
        await _writeSetting(_dirtyKey, false);
        await (database.delete(
          database.appSettings,
        )..where((setting) => setting.key.equals(_dirtySinceKey))).go();
      }
    });
    await _applyRetention(directory, state.retentionLimit);
    return _BackupRun(
      destination: destination,
      dirtyRevision: state.dirtyRevision,
    );
  }

  /// Coordinates the foreground engine and WorkManager's headless engine.
  /// SQLite's upsert is the cross-engine compare-and-set; the in-memory
  /// future above remains the fast path for calls in the same engine.
  Future<_RunLease> _acquireRunLease() async {
    final deadline = DateTime.now().toUtc().add(_runLeaseWait);
    var contended = false;
    while (true) {
      final token = const Uuid().v4();
      final acquiredAt = now().toUtc();
      final nowSeconds = acquiredAt.millisecondsSinceEpoch ~/ 1000;
      final expiresAtSeconds =
          acquiredAt.add(_runLeaseDuration).millisecondsSinceEpoch ~/ 1000;
      final value = jsonEncode({
        'token': token,
        'expiresAtEpochSeconds': expiresAtSeconds,
      });
      await database.customStatement(
        '''
          INSERT INTO app_settings(key, value_json, updated_at)
          VALUES(?, ?, ?)
          ON CONFLICT(key) DO UPDATE SET
            value_json = excluded.value_json,
            updated_at = excluded.updated_at
          WHERE COALESCE(
            CAST(json_extract(app_settings.value_json,
              '\$.expiresAtEpochSeconds') AS INTEGER),
            0
          ) <= ?
        ''',
        [automaticBackupRunLeaseSettingKey, value, nowSeconds, nowSeconds],
      );
      final row =
          await (database.select(database.appSettings)..where(
                (setting) =>
                    setting.key.equals(automaticBackupRunLeaseSettingKey),
              ))
              .getSingleOrNull();
      if (row != null) {
        final decoded = jsonDecode(row.valueJson);
        if (decoded is Map<String, dynamic> && decoded['token'] == token) {
          return _RunLease(token: token, contended: contended);
        }
      }
      contended = true;
      if (!DateTime.now().toUtc().isBefore(deadline)) {
        throw const AutomaticBackupWriteException();
      }
      await Future<void>.delayed(_runLeasePollInterval);
    }
  }

  Future<void> _releaseRunLease(String token) {
    return database.customStatement(
      '''
        DELETE FROM app_settings
        WHERE key = ? AND json_extract(value_json, '\$.token') = ?
      ''',
      [automaticBackupRunLeaseSettingKey, token],
    );
  }

  Future<String?> runIfEnabled() async {
    if (!await isEnabled()) return null;
    return runNow();
  }

  Future<void> resetAfterRestore() {
    final reset = (database.delete(
      database.appSettings,
    )..where((setting) => setting.key.isIn(_keys))).go();
    return reset.then((_) => _cancelScheduled());
  }

  Future<void> _ensureScheduled() async {
    try {
      await scheduler.ensureScheduled();
    } on Object {
      // A scheduler failure must not turn a foreground backup into a failed
      // export. The startup/next mutation path will attempt registration again.
    }
  }

  Future<void> _cancelScheduled() async {
    try {
      await scheduler.cancel();
    } on Object {
      // Cancellation is best effort; the worker re-checks enabled state before
      // doing any storage work, so a stale task is harmless.
    }
  }

  Future<void> _applyRetention(String directory, int retentionLimit) async {
    final retentionStorage = storage is BackupRetentionStorage
        ? storage as BackupRetentionStorage
        : null;
    if (retentionStorage == null) return;
    try {
      final files = await retentionStorage.listFiles(directory: directory);
      final automatic =
          files.where(_isAutomaticBackupFile).toList(growable: false)
            ..sort((first, second) {
              // Brand prefixes must not affect chronology across the rebrand.
              final order = first
                  .replaceFirst(_automaticPrefix, '')
                  .compareTo(second.replaceFirst(_automaticPrefix, ''));
              return order != 0 ? order : first.compareTo(second);
            });
      final excess = automatic.length - retentionLimit;
      if (excess <= 0) return;
      for (final fileName in automatic.take(excess)) {
        await retentionStorage.deleteFile(
          directory: directory,
          fileName: fileName,
        );
      }
    } on Object {
      // Retention is best effort. A successful backup must never be reported
      // as failed merely because listing or deleting old files is unavailable.
    }
  }

  static final _automaticPrefix = RegExp(r'^hoop(?:trace|ito)-auto-');
  static final _automaticFilePattern = RegExp(
    r'^hoop(?:trace|ito)-auto-.+\.json$',
  );

  static bool _isAutomaticBackupFile(String fileName) =>
      _automaticFilePattern.hasMatch(fileName);

  static int _clampRetentionLimit(Object? value) {
    final parsed = value is int ? value : int.tryParse('$value');
    if (parsed == null) return defaultRetentionLimit;
    return parsed.clamp(minRetentionLimit, maxRetentionLimit);
  }

  static int _nonNegativeInt(Object? value) {
    final parsed = value is int ? value : int.tryParse('$value');
    if (parsed == null || parsed < 0) return 0;
    return parsed;
  }

  static DateTime? _parseUtcDateTime(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  Future<bool> _readDirty() async {
    final query = database.select(database.appSettings)
      ..where((setting) => setting.key.equals(_dirtyKey));
    final row = await query.getSingleOrNull();
    return row != null && jsonDecode(row.valueJson) == true;
  }

  Future<_DirtyMetadata> _readDirtyMetadata() async {
    final query = database.select(database.appSettings)
      ..where(
        (setting) =>
            setting.key.isIn({_dirtyKey, _dirtyRevisionKey, _dirtySinceKey}),
      );
    final settings = {
      for (final row in await query.get()) row.key: jsonDecode(row.valueJson),
    };
    return _DirtyMetadata(
      dirty: settings[_dirtyKey] == true,
      revision: _nonNegativeInt(settings[_dirtyRevisionKey]),
      dirtySince: _parseUtcDateTime(settings[_dirtySinceKey]),
    );
  }

  Future<DateTime?> _readDirtySince() async {
    final query = database.select(database.appSettings)
      ..where((setting) => setting.key.equals(_dirtySinceKey));
    final row = await query.getSingleOrNull();
    return row == null ? null : _parseUtcDateTime(jsonDecode(row.valueJson));
  }

  Future<int> _readDirtyRevision() async {
    final query = database.select(database.appSettings)
      ..where((setting) => setting.key.equals(_dirtyRevisionKey));
    final row = await query.getSingleOrNull();
    if (row == null) return 0;
    return _nonNegativeInt(jsonDecode(row.valueJson));
  }

  Future<void> _writeSetting(String key, Object value) {
    return database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSetting(
            key: key,
            valueJson: jsonEncode(value),
            updatedAt: now().toUtc(),
          ),
        );
  }

  static String _fileTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}'
        '${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}

class _BackupRun {
  const _BackupRun({required this.destination, required this.dirtyRevision});

  final String destination;
  final int dirtyRevision;
}

class _RunLease {
  const _RunLease({required this.token, required this.contended});

  final String token;
  final bool contended;
}

class _DirtyMetadata {
  const _DirtyMetadata({
    required this.dirty,
    required this.revision,
    required this.dirtySince,
  });

  final bool dirty;
  final int revision;
  final DateTime? dirtySince;
}
