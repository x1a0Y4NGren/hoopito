import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/device_automatic_backup_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(DeviceAutomaticBackupStorage.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses the Android SAF channel for approved tree URIs', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'pickDirectory' => <String, Object?>{
              'reference': 'content://provider/tree/HoopitoTest',
              'displayName': 'HoopitoTest',
            },
            'directoryExists' => true,
            'writeBackup' => 'content://provider/document/backup.json',
            _ => throw MissingPluginException(call.method),
          };
        });
    final storage = DeviceAutomaticBackupStorage(useAndroidSaf: true);

    final selection = await storage.pickDirectory();
    expect(selection?.reference, 'content://provider/tree/HoopitoTest');
    expect(selection?.displayName, 'HoopitoTest');
    expect(await storage.directoryExists(selection!.reference), isTrue);
    expect(
      await storage.write(
        directory: selection.reference,
        fileName: 'hoopito-auto-20260824T120000Z.json',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
      'content://provider/document/backup.json',
    );
    expect(calls.map((call) => call.method), [
      'pickDirectory',
      'directoryExists',
      'writeBackup',
    ]);
    expect(
      (calls.last.arguments as Map<Object?, Object?>)['bytes'],
      Uint8List.fromList([1, 2, 3]),
    );
  });

  test(
    'resolves the production database path without native plugins',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return '/data/user/0/hooptrace/app_flutter/hooptrace.sqlite';
          });

      expect(
        await DeviceAutomaticBackupStorage.resolveBackgroundDatabasePath(),
        '/data/user/0/hooptrace/app_flutter/hooptrace.sqlite',
      );
      expect(calls.map((call) => call.method), ['backgroundDatabasePath']);
    },
  );

  test(
    'lists and deletes automatic backup files through the Android SAF channel',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'listBackupFiles' => <Object?>[
                'hoopito-auto-20260824T120000Z.json',
                'notes.txt',
              ],
              'deleteBackupFile' => null,
              _ => throw MissingPluginException(call.method),
            };
          });
      final storage = DeviceAutomaticBackupStorage(useAndroidSaf: true);

      expect(
        await storage.listFiles(
          directory: 'content://provider/tree/HoopitoTest',
        ),
        ['hoopito-auto-20260824T120000Z.json', 'notes.txt'],
      );
      await storage.deleteFile(
        directory: 'content://provider/tree/HoopitoTest',
        fileName: 'hoopito-auto-20260824T120000Z.json',
      );

      expect(calls.map((call) => call.method), [
        'listBackupFiles',
        'deleteBackupFile',
      ]);
      expect(
        (calls.first.arguments as Map<Object?, Object?>)['directory'],
        'content://provider/tree/HoopitoTest',
      );
      expect(
        (calls.last.arguments as Map<Object?, Object?>)['fileName'],
        'hoopito-auto-20260824T120000Z.json',
      );
    },
  );

  test('skips non-automatic and path-traversal delete requests', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    final storage = DeviceAutomaticBackupStorage(useAndroidSaf: true);

    await storage.deleteFile(
      directory: 'content://provider/tree/HoopitoTest',
      fileName: 'notes.txt',
    );
    await storage.deleteFile(
      directory: 'content://provider/tree/HoopitoTest',
      fileName: 'hoopito-auto-good.json/../notes.txt',
    );
    await storage.deleteFile(
      directory: 'content://provider/tree/HoopitoTest',
      fileName: r'hoopito-auto-good.json\..\notes.txt',
    );

    expect(calls, isEmpty);
  });

  test('delegates retention operations to a non-SAF fallback', () async {
    final fallback = _RetentionFallback();
    final storage = DeviceAutomaticBackupStorage(
      fallback: fallback,
      useAndroidSaf: false,
    );

    expect(await storage.listFiles(directory: '/backups'), ['a.json']);
    await storage.deleteFile(
      directory: '/backups',
      fileName: 'hoopito-auto-a.json',
    );

    expect(fallback.deleted, ['/backups/hoopito-auto-a.json']);
  });

  test('rejects legacy Android filesystem paths', () async {
    final storage = DeviceAutomaticBackupStorage(useAndroidSaf: true);

    expect(
      await storage.directoryExists('/storage/emulated/0/HoopitoTest'),
      isFalse,
    );
    expect(
      () => storage.write(
        directory: '/storage/emulated/0/HoopitoTest',
        fileName: 'hoopito-backup-legacy.json',
        bytes: Uint8List(0),
      ),
      throwsA(isA<BackupDirectoryUnavailableException>()),
    );
    expect(
      () => storage.listFiles(directory: '/storage/emulated/0/HoopitoTest'),
      throwsA(isA<BackupDirectoryUnavailableException>()),
    );
    expect(
      () => storage.deleteFile(
        directory: '/storage/emulated/0/HoopitoTest',
        fileName: 'hoopito-auto-backup.json',
      ),
      throwsA(isA<BackupDirectoryUnavailableException>()),
    );
  });

  test(
    'rejects unsafe or non-backup Android write names before channel call',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return 'unexpected';
          });
      final storage = DeviceAutomaticBackupStorage(useAndroidSaf: true);

      for (final fileName in [
        '',
        'backup.json',
        'hoopito-auto-.json',
        'hoopito-auto-good.json/../escape.json',
        r'hoopito-backup-good.json\..\escape.json',
        'hoopito-safety-backup-good\u0000.json',
        'hoopito-auto-good.txt',
      ]) {
        await expectLater(
          storage.write(
            directory: 'content://provider/tree/HoopitoTest',
            fileName: fileName,
            bytes: Uint8List(0),
          ),
          throwsA(isA<AutomaticBackupWriteException>()),
          reason: 'unsafe filename should be rejected: $fileName',
        );
      }

      expect(calls, isEmpty);
    },
  );
}

class _RetentionFallback
    implements AutomaticBackupStorage, BackupRetentionStorage {
  final deleted = <String>[];

  @override
  Future<bool> directoryExists(String path) async => true;

  @override
  Future<String> write({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  }) async => '$directory/$fileName';

  @override
  Future<List<String>> listFiles({required String directory}) async => [
    'a.json',
  ];

  @override
  Future<void> deleteFile({
    required String directory,
    required String fileName,
  }) async {
    deleted.add('$directory/$fileName');
  }
}
