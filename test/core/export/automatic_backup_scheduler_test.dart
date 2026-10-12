import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/automatic_backup_scheduler.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';

import '../../test_helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android scheduler registers and cancels one durable task', () async {
    final calls = <String>[];
    final channel = MethodChannel(DeviceAutomaticBackupScheduler.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final scheduler = DeviceAutomaticBackupScheduler(useAndroid: true);
    await scheduler.ensureScheduled();
    await scheduler.cancel();

    expect(calls, ['scheduleAutomaticBackup', 'cancelAutomaticBackup']);
  });

  test('non-Android scheduler is a no-op', () async {
    final channel = MethodChannel(DeviceAutomaticBackupScheduler.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var invoked = false;
    messenger.setMockMethodCallHandler(channel, (_) async {
      invoked = true;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final scheduler = DeviceAutomaticBackupScheduler(useAndroid: false);
    await scheduler.ensureScheduled();
    await scheduler.cancel();

    expect(invoked, isFalse);
  });

  test(
    'service keeps the durable task aligned with enable, dirty, and disable',
    () async {
      final database = createTestDatabase();
      final storage = _MemoryStorage()..directories.add('/approved');
      final scheduler = _RecordingScheduler();
      final service = AutomaticBackupService(
        database,
        JsonBackupCodec(database, appVersion: '0.1.0+1'),
        storage: storage,
        scheduler: scheduler,
      );

      await service.configureDirectory('/approved');
      await service.enable();
      await service.markDirty();
      await service.disable();

      expect(scheduler.ensureCount, 2);
      expect(scheduler.cancelCount, 1);
    },
  );
}

class _RecordingScheduler implements AutomaticBackupScheduler {
  var ensureCount = 0;
  var cancelCount = 0;

  @override
  Future<void> ensureScheduled() async => ensureCount++;

  @override
  Future<void> cancel() async => cancelCount++;
}

class _MemoryStorage implements AutomaticBackupStorage {
  final directories = <String>{};

  @override
  Future<bool> directoryExists(String path) async => directories.contains(path);

  @override
  Future<String> write({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  }) async => '$directory/$fileName';
}
