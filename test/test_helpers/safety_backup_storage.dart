import 'dart:typed_data';

import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/export/safety_backup_store.dart';

SafetyBackupStore createTestSafetyBackupStore(JsonBackupCodec codec) =>
    SafetyBackupStore(codec, storage: MemorySafetyBackupStorage());

/// Widget tests control file I/O so fake time never waits on the host disk.
/// File publication and readback validation still run in SafetyBackupStore.
class MemorySafetyBackupStorage implements SafetyBackupStorage {
  final files = <String, Uint8List>{};

  @override
  Future<void> delete(String fileName) async {
    files.remove(fileName);
  }

  @override
  Future<List<String>> listFiles() async => files.keys.toList();

  @override
  Future<void> publish(String temporaryName, String fileName) async {
    files[fileName] = files.remove(temporaryName)!;
  }

  @override
  Future<Uint8List> read(String fileName, {required int maxBytes}) async {
    final bytes = files[fileName]!;
    if (bytes.length > maxBytes) {
      throw BackupCapacityException(
        limitKind: BackupCapacityLimit.payloadBytes,
        measured: bytes.length,
        limit: maxBytes,
      );
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> writeAndFlush(String fileName, Uint8List bytes) async {
    files[fileName] = Uint8List.fromList(bytes);
  }
}
