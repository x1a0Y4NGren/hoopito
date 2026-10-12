import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hoopito/app/app_metadata.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/entry/entry_diagnostic_binding.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/app_database_provider.dart';
import 'package:hoopito/core/diagnostics/startup_diagnostics.dart';
import 'package:hoopito/core/export/automatic_backup_scheduler.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/device_automatic_backup_storage.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/settings/motion_preference_cache.dart';

void main(List<String> arguments) {
  if (StartupDiagnostics.enabled &&
      entryAnimationEnabledFromEntrypointArguments(arguments)) {
    EntryDiagnosticBinding();
  }
  runApp(
    HoopitoApp(
      showEntryAnimation: entryAnimationEnabledFromEntrypointArguments(
        arguments,
      ),
      initialMotionPreference: motionPreferenceFromEntrypointArguments(
        arguments,
      ),
    ),
  );
}

/// WorkManager starts this entrypoint in a short-lived headless engine. It
/// opens the same Drift file and uses the registered storage-only SAF channel;
/// no activity or document picker is needed for a due backup.
@pragma('vm:entry-point')
Future<void> automaticBackupBackgroundMain() async {
  final completionChannel = MethodChannel(
    DeviceAutomaticBackupScheduler.backgroundChannelName,
  );
  AppDatabase? database;
  var outcome = 'retry';
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final databasePath =
        await DeviceAutomaticBackupStorage.resolveBackgroundDatabasePath();
    database = await openNativeAppDatabaseAt(File(databasePath));
    final storage = DeviceAutomaticBackupStorage(useAndroidSaf: true);
    final service = AutomaticBackupService(
      database,
      JsonBackupCodec(database, appVersion: hoopitoAppVersion),
      storage: storage,
      scheduler: DeviceAutomaticBackupScheduler(useAndroid: true),
    );
    await service.runIfDue();
    outcome = 'success';
  } on BackupDirectoryNotConfiguredException {
    outcome = 'missing_authorization';
  } on BackupDirectoryUnavailableException {
    outcome = 'missing_authorization';
  } on Object {
    outcome = 'retry';
  } finally {
    try {
      await database?.close();
    } finally {
      await completionChannel.invokeMethod<void>('completed', {
        'outcome': outcome,
      });
    }
  }
}
