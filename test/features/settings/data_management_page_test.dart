import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/features/settings/data_management_page.dart';
import 'package:hoopito/features/settings/settings_controller.dart';

import '../../test_helpers/test_database.dart';
import '../../test_helpers/safety_backup_storage.dart';

void main() {
  testWidgets(
    'English restore chooser fits narrow landscape at 200 percent text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createTestDatabase();
      final codec = JsonBackupCodec(database, appVersion: '1.1.0+3');
      final backup = AutomaticBackupService(
        database,
        codec,
        storage: _Storage(),
      );
      final controller = SettingsController(
        exports: ExportCoordinator(
          database,
          codec,
          safetyBackups: createTestSafetyBackupStore(codec),
          gateway: _Gateway(),
          automaticBackup: backup,
        ),
        automaticBackup: backup,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        await database.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: DataManagementPage(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('data-restore-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('data-restore-row')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('backup-mode-merge')), findsOneWidget);
      expect(find.byKey(const Key('backup-mode-replace')), findsOneWidget);
      final replace = find.byKey(const Key('backup-mode-replace'));
      await tester.ensureVisible(replace);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(replace).dy, greaterThanOrEqualTo(0));
      expect(tester.getBottomRight(replace).dy, lessThanOrEqualTo(400));
      await tester.tap(replace);
      await tester.pumpAndSettle();
      expect(find.text('Replace all local data?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Replace all local data?'), findsNothing);
    },
  );

  testWidgets(
    'data hub remains usable in compact landscape and at large text',
    (tester) async {
      final database = createTestDatabase();
      final codec = JsonBackupCodec(database, appVersion: '1.1.0+3');
      final backup = AutomaticBackupService(
        database,
        codec,
        storage: _Storage(),
      );
      final controller = SettingsController(
        exports: ExportCoordinator(
          database,
          codec,
          safetyBackups: createTestSafetyBackupStore(codec),
          gateway: _Gateway(),
          automaticBackup: backup,
        ),
        automaticBackup: backup,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.binding.setSurfaceSize(null);
        controller.dispose();
        await database.close();
      });

      for (final (size, locale, brightness, scale) in [
        (const Size(390, 844), const Locale('en'), Brightness.light, 2.0),
        (const Size(731, 411), const Locale('zh'), Brightness.dark, 2.0),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: ThemeData(brightness: brightness),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: DataManagementPage(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final retention = find.byKey(const Key('backup-retention-limit'));
        await tester.scrollUntilVisible(
          retention,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.getSize(retention).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'backup now is visibly and semantically disabled until configured',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createTestDatabase();
      final codec = JsonBackupCodec(database, appVersion: '1.1.0+3');
      final backup = AutomaticBackupService(
        database,
        codec,
        storage: _Storage(),
      );
      final controller = SettingsController(
        exports: ExportCoordinator(
          database,
          codec,
          safetyBackups: createTestSafetyBackupStore(codec),
          gateway: _Gateway(),
          automaticBackup: backup,
        ),
        automaticBackup: backup,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        await database.close();
      });
      await tester.pumpWidget(
        MaterialApp(home: DataManagementPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      final row = find.byKey(const Key('settings-backup-now-row'));
      await tester.ensureVisible(row);
      final semantics = tester.getSemantics(row);
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(
        semantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isFalse,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byKey(const Key('setting-disabled-cue')),
        ),
        findsOneWidget,
      );
      expect(find.text('请先选择自动备份文件夹'), findsOneWidget);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    },
  );

  testWidgets('automatic backup configuration remains functional in the hub', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createTestDatabase();
    final gateway = _Gateway()
      ..pickedDirectory = const BackupDirectorySelection(
        reference: '/approved',
        displayName: 'Approved backups',
      );
    final storage = _Storage()..availableDirectories.add('/approved');
    final codec = JsonBackupCodec(database, appVersion: '1.1.0+3');
    final backup = AutomaticBackupService(database, codec, storage: storage);
    final controller = SettingsController(
      exports: ExportCoordinator(
        database,
        codec,
        safetyBackups: createTestSafetyBackupStore(codec),
        gateway: gateway,
        automaticBackup: backup,
      ),
      automaticBackup: backup,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      MaterialApp(home: DataManagementPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('automatic-backup-switch')));
    await tester.pumpAndSettle();

    expect(controller.backupState.enabled, isTrue);
    expect(controller.backupState.directory, '/approved');
    expect(storage.writeCount, 1);

    await tester.tap(find.byKey(const Key('settings-backup-now-row')));
    await tester.pumpAndSettle();
    expect(storage.writeCount, 2);
  });

  testWidgets('restore chooser keeps merge available during an active match', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createTestDatabase();
    final codec = JsonBackupCodec(database, appVersion: '1.1.0+3');
    final backup = AutomaticBackupService(database, codec, storage: _Storage());
    final controller = SettingsController(
      exports: ExportCoordinator(
        database,
        codec,
        safetyBackups: createTestSafetyBackupStore(codec),
        gateway: _Gateway(),
        automaticBackup: backup,
      ),
      automaticBackup: backup,
      canRestoreBackup: false,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      MaterialApp(home: DataManagementPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('data-restore-row')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('backup-mode-merge')))
          .enabled,
      isTrue,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('backup-mode-replace')))
          .enabled,
      isFalse,
    );
  });

  testWidgets('data hub separates restore from automatic backup controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createTestDatabase();
    final gateway = _Gateway();
    final codec = JsonBackupCodec(database, appVersion: '1.1.0+3');
    final backup = AutomaticBackupService(database, codec, storage: _Storage());
    final controller = SettingsController(
      exports: ExportCoordinator(
        database,
        codec,
        safetyBackups: createTestSafetyBackupStore(codec),
        gateway: gateway,
        automaticBackup: backup,
      ),
      automaticBackup: backup,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      MaterialApp(home: DataManagementPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('导出与恢复'), findsOneWidget);
    expect(find.text('从备份恢复'), findsOneWidget);
    expect(find.text('自动备份设置'), findsOneWidget);
    expect(find.byKey(const Key('automatic-backup-switch')), findsOneWidget);
    expect(find.text('备份位置'), findsOneWidget);
    expect(find.byKey(const Key('settings-backup-now-row')), findsOneWidget);
    expect(find.byKey(const Key('backup-retention-dropdown')), findsOneWidget);
  });

  testWidgets('data hub selects one manual export format at a time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createTestDatabase();
    final gateway = _Gateway();
    final codec = JsonBackupCodec(database, appVersion: '1.1.0+3');
    final backup = AutomaticBackupService(database, codec, storage: _Storage());
    final controller = SettingsController(
      exports: ExportCoordinator(
        database,
        codec,
        safetyBackups: createTestSafetyBackupStore(codec),
        gateway: gateway,
        automaticBackup: backup,
      ),
      automaticBackup: backup,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      MaterialApp(home: DataManagementPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('导出数据'), findsOneWidget);
    expect(find.byKey(const Key('data-export-row')), findsOneWidget);
    await tester.tap(find.byKey(const Key('data-export-row')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('data-export-json')), findsOneWidget);
    expect(find.byKey(const Key('data-export-csv')), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(gateway.shared, isEmpty);

    await tester.tap(find.byKey(const Key('data-export-row')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('data-export-json')));
    await tester.pumpAndSettle();
    expect(gateway.shared, hasLength(1));
    expect(gateway.shared.single, hasLength(1));
    expect(gateway.shared.single.single.fileName, endsWith('.json'));
    expect(gateway.shared.single.single.mimeType, 'application/json');

    await tester.tap(find.byKey(const Key('data-export-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('data-export-csv')));
    await tester.pumpAndSettle();
    expect(gateway.shared, hasLength(2));
    expect(gateway.shared.last, hasLength(3));
    expect(
      gateway.shared.last.every((artifact) => artifact.mimeType == 'text/csv'),
      isTrue,
    );

    gateway.failNextShare = true;
    await tester.tap(find.byKey(const Key('data-export-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('data-export-json')));
    await tester.pumpAndSettle();
    expect(gateway.shared, hasLength(2));
    expect(gateway.shareAttempts, 3);
    expect(find.byKey(const Key('data-export-row')), findsOneWidget);

    await tester.tap(find.byKey(const Key('data-export-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('data-export-json')));
    await tester.pumpAndSettle();
    expect(gateway.shared, hasLength(3));
    expect(gateway.shareAttempts, 4);
  });
}

class _Gateway implements ExportGateway {
  final shared = <List<ExportArtifact>>[];
  BackupDirectorySelection? pickedDirectory;
  bool failNextShare = false;
  int shareAttempts = 0;

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
  }) async {
    shareAttempts++;
    if (failNextShare) {
      failNextShare = false;
      throw StateError('Share failed');
    }
    shared.add(List.unmodifiable(artifacts));
  }
}

class _Storage implements AutomaticBackupStorage {
  final availableDirectories = <String>{};
  int writeCount = 0;

  @override
  Future<bool> directoryExists(String path) async =>
      availableDirectories.contains(path);

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
