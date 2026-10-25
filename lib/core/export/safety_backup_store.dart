import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

export 'package:hoopito/core/export/json_backup_codec.dart'
    show SafetyBackupWriteException;

/// Metadata for an internal snapshot whose contents have passed validation.
class SafetyBackup {
  const SafetyBackup({
    required this.fileName,
    required this.exportedAt,
    required this.recordCounts,
    required this.payloadBytes,
  });

  String get id => fileName;
  final String fileName;
  final DateTime exportedAt;
  final Map<String, int> recordCounts;
  final int payloadBytes;
}

/// File operations are separate so disk failures can be exercised without
/// replacing the real codec, publication sequence or replacement transaction.
abstract interface class SafetyBackupStorage {
  Future<List<String>> listFiles();
  Future<Uint8List> read(String fileName, {required int maxBytes});
  Future<void> writeAndFlush(String fileName, Uint8List bytes);
  Future<void> publish(String temporaryName, String fileName);
  Future<void> delete(String fileName);
}

class IoSafetyBackupStorage implements SafetyBackupStorage {
  IoSafetyBackupStorage({Future<Directory> Function()? resolveDirectory})
    : _resolveDirectory = resolveDirectory ?? _applicationDirectory;

  final Future<Directory> Function() _resolveDirectory;
  Future<Directory>? _directory;

  Future<Directory> _directoryOnce() => _directory ??= _resolveDirectory();

  static Future<Directory> _applicationDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    // Keep the private location so pre-rebrand rollback snapshots remain usable.
    return Directory(path.join(documents.path, 'hooptrace-safety-backups'));
  }

  Future<File> _file(String fileName) async {
    if (path.basename(fileName) != fileName ||
        !_internalFilePattern.hasMatch(fileName)) {
      throw const BackupValidationException('Invalid internal backup name.');
    }
    return File(path.join((await _directoryOnce()).path, fileName));
  }

  @override
  Future<List<String>> listFiles() async {
    final directory = await _directoryOnce();
    if (!await directory.exists()) return const [];
    return [
      await for (final entry in directory.list(followLinks: false))
        if (entry is File) path.basename(entry.path),
    ];
  }

  @override
  Future<Uint8List> read(String fileName, {required int maxBytes}) async {
    final file = await _file(fileName);
    final measured = await file.length();
    if (measured > maxBytes) {
      throw BackupCapacityException(
        limitKind: BackupCapacityLimit.payloadBytes,
        measured: measured,
        limit: maxBytes,
      );
    }
    return file.readAsBytes();
  }

  @override
  Future<void> writeAndFlush(String fileName, Uint8List bytes) async {
    final file = await _file(fileName);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> publish(String temporaryName, String fileName) async {
    final temporary = await _file(temporaryName);
    final destination = await _file(fileName);
    // Both paths are inside the same private directory: rename publishes the
    // complete verified file atomically, never a partially written snapshot.
    await temporary.rename(destination.path);
  }

  @override
  Future<void> delete(String fileName) async {
    final file = await _file(fileName);
    if (await file.exists()) await file.delete();
  }

  static final _internalFilePattern = RegExp(
    r'^hoop(?:trace|ito)-safety-backup-[A-Za-z0-9_-]+\.json(?:\.tmp)?$',
  );
}

class SafetyBackupStore {
  SafetyBackupStore(this.codec, {SafetyBackupStorage? storage})
    : storage = storage ?? IoSafetyBackupStorage();

  static const retentionLimit = 2;
  final JsonBackupCodec codec;
  final SafetyBackupStorage storage;

  Future<SafetyBackup> save(String source) async {
    final document = codec.decodeAndValidate(source);
    final stamp = document.manifest.exportedAt.toUtc().microsecondsSinceEpoch;
    final fileName = 'hoopito-safety-backup-$stamp-${const Uuid().v4()}.json';
    final temporaryName = '$fileName.tmp';
    final bytes = Uint8List.fromList(utf8.encode(source));
    try {
      await storage.writeAndFlush(temporaryName, bytes);
      final readback = await storage.read(
        temporaryName,
        maxBytes: codec.maxPayloadBytes,
      );
      final verified = codec.decodeAndValidate(
        utf8.decode(readback, allowMalformed: false),
      );
      if (verified.checksum != document.checksum) {
        throw const BackupChecksumException();
      }
      await storage.publish(temporaryName, fileName);
      return _metadata(fileName, verified, readback.length);
    } on Object {
      throw const SafetyBackupWriteException();
    } finally {
      try {
        await storage.delete(temporaryName);
      } on Object {
        // A leftover temporary file is never included in the recovery list.
      }
    }
  }

  Future<String> read(SafetyBackup backup) async {
    _requireSnapshotName(backup.fileName);
    final bytes = await storage.read(
      backup.fileName,
      maxBytes: codec.maxPayloadBytes,
    );
    final source = utf8.decode(bytes, allowMalformed: false);
    codec.decodeAndValidate(source);
    return source;
  }

  Future<List<SafetyBackup>> list() async {
    final snapshots = <SafetyBackup>[];
    for (final name in await storage.listFiles()) {
      if (!_snapshotPattern.hasMatch(name)) continue;
      try {
        final bytes = await storage.read(name, maxBytes: codec.maxPayloadBytes);
        final document = codec.decodeAndValidate(
          utf8.decode(bytes, allowMalformed: false),
        );
        snapshots.add(_metadata(name, document, bytes.length));
      } on Object {
        // Corrupt, oversized and incomplete files must not be offered as
        // recoverable. A selected snapshot is validated again before restore.
      }
    }
    snapshots.sort((first, second) {
      final time = second.exportedAt.compareTo(first.exportedAt);
      return time != 0 ? time : second.fileName.compareTo(first.fileName);
    });
    return snapshots;
  }

  /// Called only after the protected database replacement has committed.
  Future<void> retainLatest() async {
    final snapshots = await list();
    for (final snapshot in snapshots.skip(retentionLimit)) {
      await storage.delete(snapshot.fileName);
    }
  }

  static SafetyBackup _metadata(
    String fileName,
    JsonBackupDocument document,
    int payloadBytes,
  ) => SafetyBackup(
    fileName: fileName,
    exportedAt: document.manifest.exportedAt,
    recordCounts: Map.unmodifiable(document.manifest.recordCounts),
    payloadBytes: payloadBytes,
  );

  static void _requireSnapshotName(String fileName) {
    if (!_snapshotPattern.hasMatch(fileName)) {
      throw const BackupValidationException('Invalid internal backup name.');
    }
  }

  static final _snapshotPattern = RegExp(
    r'^hoop(?:trace|ito)-safety-backup-[A-Za-z0-9_-]+\.json$',
  );
}
