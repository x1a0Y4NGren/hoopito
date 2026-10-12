import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_en.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/export_coordinator.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/features/settings/data_management_page.dart';
import 'package:hoopito/features/settings/settings_controller.dart';
import 'package:hoopito/features/settings/settings_error_message.dart';

import '../../test_helpers/test_database.dart';

void main() {
  for (final language in ['zh', 'en']) {
    testWidgets(
      '$language safety restore fits narrow landscape and confirms replacement',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final fixture = _Fixture();
        await fixture.seedSafetyCopy();
        await fixture.controller.load();
        var restored = 0;
        final l10n = language == 'zh'
            ? AppLocalizationsZh()
            : AppLocalizationsEn();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: DataManagementPage(
              controller: fixture.controller,
              onDataRestored: () => restored++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byKey(
          Key('safety-backup-${fixture.controller.safetyBackups.single.id}'),
        );
        await tester.scrollUntilVisible(
          row,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text(l10n.v2SafetyConfirm), findsOneWidget);
        await tester.tap(find.text(l10n.cancelAction));
        await tester.pumpAndSettle();
        expect(
          (await fixture.database.select(fixture.database.players).get())
              .single
              .id,
          'current',
        );
        expect(fixture.controller.safetyBackups, hasLength(1));

        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('safety-backup-confirm')),
        );
        await tester.tap(find.byKey(const Key('safety-backup-confirm')));
        await tester.pumpAndSettle();
        expect(
          (await fixture.database.select(fixture.database.players).get())
              .single
              .id,
          'original',
        );
        expect(fixture.controller.safetyBackups, hasLength(2));
        expect(fixture.controller.busy, isFalse);
        expect(restored, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'active match disables safety restore while preserving its visible copy',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final fixture = _Fixture(canRestore: false);
      await fixture.seedSafetyCopy();
      await fixture.controller.load();
      await tester.pumpWidget(
        MaterialApp(home: DataManagementPage(controller: fixture.controller)),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(
        Key('safety-backup-${fixture.controller.safetyBackups.single.id}'),
      );
      await tester.ensureVisible(row);
      expect(
        tester.getSemantics(row).flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-backup-confirm')), findsNothing);
      expect(
        (await fixture.database.select(fixture.database.players).get())
            .single
            .id,
        'current',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );

  testWidgets('failed safety save reports preserved data and allows retry', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.seedSafetyCopy();
    await fixture.controller.load();
    fixture.storage.failWrite = true;
    await tester.pumpWidget(
      MaterialApp(home: DataManagementPage(controller: fixture.controller)),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(
      Key('safety-backup-${fixture.controller.safetyBackups.single.id}'),
    );
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-backup-confirm')));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsZh().v2SafetyWriteError), findsOneWidget);
    expect(
      (await fixture.database.select(fixture.database.players).get()).single.id,
      'current',
    );
    expect(fixture.controller.busy, isFalse);
    expect(fixture.controller.safetyBackups, hasLength(1));
    fixture.storage.failWrite = false;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-backup-confirm')));
    await tester.pumpAndSettle();
    expect(
      (await fixture.database.select(fixture.database.players).get()).single.id,
      'original',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'unavailable safety list shows retry and keeps other settings usable',
    (tester) async {
      final fixture = _Fixture();
      fixture.storage.failList = true;
      await fixture.controller.load();
      expect(fixture.controller.initialized, isTrue);
      await tester.pumpWidget(
        MaterialApp(home: DataManagementPage(controller: fixture.controller)),
      );
      await tester.pumpAndSettle();
      final retry = find.byKey(const Key('safety-backup-retry'));
      await tester.ensureVisible(retry);
      expect(find.text(AppLocalizationsZh().v2SafetyLoadError), findsOneWidget);
      fixture.storage.failList = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(fixture.controller.safetyBackupError, isNull);
      expect(find.text(AppLocalizationsZh().v2SafetyEmpty), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('capacity messages explain measured bytes and rows in both locales', () {
    const bytes = BackupCapacityException(
      limitKind: BackupCapacityLimit.payloadBytes,
      measured: 34 * 1024 * 1024,
      limit: 32 * 1024 * 1024,
    );
    const rows = BackupCapacityException(
      limitKind: BackupCapacityLimit.rowsPerTable,
      measured: 100001,
      limit: 100000,
      tableName: 'matchEvents',
    );
    expect(
      settingsFriendlyError(bytes, AppLocalizationsEn()),
      contains('34.00 MiB'),
    );
    expect(
      settingsFriendlyError(bytes, AppLocalizationsZh()),
      contains('32.00 MiB'),
    );
    expect(
      settingsFriendlyError(rows, AppLocalizationsEn()),
      contains('100,001 rows'),
    );
    expect(
      settingsFriendlyError(rows, AppLocalizationsZh()),
      contains('100,000 行'),
    );
  });
}

class _Fixture {
  _Fixture({bool canRestore = true}) {
    database = createTestDatabase();
    codec = JsonBackupCodec(database, appVersion: '2.0.0', now: () => now);
    final automatic = AutomaticBackupService(database, codec);
    exports = ExportCoordinator(
      database,
      codec,
      gateway: _Gateway(),
      automaticBackup: automatic,
      safetyBackups: SafetyBackupStore(codec, storage: storage),
    );
    controller = SettingsController(
      exports: exports,
      automaticBackup: automatic,
      canRestoreBackup: canRestore,
    );
    addTearDown(controller.dispose);
  }
  late AppDatabase database;
  late JsonBackupCodec codec;
  late ExportCoordinator exports;
  late SettingsController controller;
  final storage = _MemorySafetyStorage();
  DateTime now = DateTime.utc(2026, 9, 24);

  Future<void> seedSafetyCopy() async {
    await database
        .into(database.players)
        .insert(
          PlayerRow(id: 'original', nickname: 'Original', createdAt: now),
        );
    await exports.safetyBackups.save(await codec.export());
    await database.delete(database.players).go();
    await database
        .into(database.players)
        .insert(PlayerRow(id: 'current', nickname: 'Current', createdAt: now));
    now = now.add(const Duration(seconds: 1));
  }
}

class _Gateway implements ExportGateway {
  @override
  Future<ExportArtifact?> pickBackup({String? dialogTitle}) async => null;
  @override
  Future<BackupDirectorySelection?> pickDirectory({
    String? dialogTitle,
  }) async => null;
  @override
  Future<void> share(
    List<ExportArtifact> artifacts, {
    required String subject,
  }) async {}
}

class _MemorySafetyStorage implements SafetyBackupStorage {
  final files = <String, Uint8List>{};
  bool failWrite = false;
  bool failList = false;
  @override
  Future<void> delete(String fileName) async {
    files.remove(fileName);
  }

  @override
  Future<List<String>> listFiles() async {
    if (failList) throw StateError('Unavailable safety directory');
    return files.keys.toList();
  }

  @override
  Future<void> publish(String temporaryName, String fileName) async {
    files[fileName] = files.remove(temporaryName)!;
  }

  @override
  Future<Uint8List> read(String fileName, {required int maxBytes}) async =>
      Uint8List.fromList(files[fileName]!);
  @override
  Future<void> writeAndFlush(String fileName, Uint8List bytes) async {
    if (failWrite) throw StateError('Disk full');
    files[fileName] = Uint8List.fromList(bytes);
  }
}
