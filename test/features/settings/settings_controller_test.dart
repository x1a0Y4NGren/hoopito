import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/features/settings/settings_controller.dart';

import '../../test_helpers/test_database.dart';
import '../../test_helpers/safety_backup_storage.dart';

void main() {
  late AppDatabase database;
  late _Gateway gateway;
  late _Storage storage;
  late AutomaticBackupService automaticBackup;
  late ScoringFeedbackService feedback;
  late SettingsController controller;

  setUp(() {
    database = createTestDatabase();
    gateway = _Gateway();
    storage = _Storage();
    final codec = JsonBackupCodec(database, appVersion: '0.1.0+1');
    automaticBackup = AutomaticBackupService(database, codec, storage: storage);
    feedback = ScoringFeedbackService(
      ScoringFeedbackPreferencesRepository(database),
    );
    controller = SettingsController(
      exports: ExportCoordinator(
        database,
        codec,
        safetyBackups: createTestSafetyBackupStore(codec),
        gateway: gateway,
        automaticBackup: automaticBackup,
      ),
      automaticBackup: automaticBackup,
      feedback: feedback,
    );
  });

  tearDown(() async {
    controller.dispose();
  });

  test('loads disabled automatic backup state by default', () async {
    await controller.load();

    expect(controller.initialized, isTrue);
    expect(controller.backupState.enabled, isFalse);
    expect(controller.backupState.directory, isNull);
    expect(controller.feedbackState.haptic, isTrue);
    expect(controller.feedbackState.sound, isFalse);
  });

  test('concurrent page loads share one in-flight operation', () async {
    final first = controller.load();
    final second = controller.load();

    await Future.wait([first, second]);

    expect(controller.initialized, isTrue);
    expect(controller.busy, isFalse);
  });

  test(
    'feedback switches persist and update the shared service cache',
    () async {
      await controller.load();

      expect(await controller.setHapticFeedbackEnabled(false), isTrue);
      expect(await controller.setSoundFeedbackEnabled(true), isTrue);
      expect(controller.feedbackState.haptic, isFalse);
      expect(controller.feedbackState.sound, isTrue);
      expect(await feedback.load(), controller.feedbackState);
      expect(
        await ScoringFeedbackPreferencesRepository(database).load(),
        controller.feedbackState,
      );
    },
  );

  test(
    'motion preference delegates to feedback service and persists',
    () async {
      await controller.load();

      expect(
        await controller.setMotionPreference(MotionPreference.reduced),
        isTrue,
      );
      expect(controller.feedbackState.motion, MotionPreference.reduced);
      expect((await feedback.load()).motion, MotionPreference.reduced);
      expect(
        (await ScoringFeedbackPreferencesRepository(database).load()).motion,
        MotionPreference.reduced,
      );
    },
  );

  test(
    'enabling prompts for and stores a directory before first backup',
    () async {
      gateway.pickedDirectory = const BackupDirectorySelection(
        reference: '/approved',
        displayName: 'Approved backups',
      );
      storage.availableDirectories.add('/approved');
      await controller.load();

      expect(await controller.setAutomaticBackupEnabled(true), isTrue);

      expect(controller.backupState.enabled, isTrue);
      expect(controller.backupState.directory, '/approved');
      expect(controller.backupState.directoryLabel, 'Approved backups');
      expect(storage.writeCount, 1);
    },
  );

  test('cancelled directory picker leaves automatic backup disabled', () async {
    await controller.load();

    expect(await controller.setAutomaticBackupEnabled(true), isFalse);
    expect(controller.backupState.enabled, isFalse);
  });

  test('backup retention is configurable and clamped to safe bounds', () async {
    await controller.load();

    await controller.setBackupRetentionLimit(100);
    expect(controller.backupState.retentionLimit, 50);

    await controller.setBackupRetentionLimit(0);
    expect(controller.backupState.retentionLimit, 1);
  });

  test('blocks restore while a match is active', () async {
    final blocked = SettingsController(
      exports: controller.exports,
      automaticBackup: automaticBackup,
      canRestoreBackup: false,
    );
    addTearDown(blocked.dispose);
    await blocked.load();

    expect(
      () => blocked.restoreBackup(
        safetySubject: 'Hoopito safety backup before restore',
      ),
      throwsA(isA<BackupRestoreBlockedException>()),
    );
    expect(
      await blocked.restoreBackup(
        mode: RestoreMode.merge,
        safetySubject: 'Hoopito safety backup before restore',
      ),
      isFalse,
    );
  });
}

class _Gateway implements ExportGateway {
  BackupDirectorySelection? pickedDirectory;

  @override
  Future<ExportArtifact?> pickBackup({String? dialogTitle}) async => null;

  @override
  Future<BackupDirectorySelection?> pickDirectory({
    String? dialogTitle,
  }) async => pickedDirectory;

  @override
  Future<void> share(
    List<ExportArtifact> artifacts, {
    required String subject,
  }) async {}
}

class _Storage implements AutomaticBackupStorage {
  final availableDirectories = <String>{};
  int writeCount = 0;

  @override
  Future<bool> directoryExists(String path) async {
    return availableDirectories.contains(path);
  }

  @override
  Future<String> write({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  }) async {
    writeCount++;
    return '$directory/$fileName';
  }
}
