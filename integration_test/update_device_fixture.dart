// Manual device fixture: build only with an explicit --target. Never shipped.
// Drives the real native channel without adding production testing hooks.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hoopito/core/data/app_database_provider.dart';

const _channel = MethodChannel('io.github.x1a0y4ngren.hooptrace/app_update');
const _package = 'io.github.x1a0y4ngren.hooptrace';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: UpdateDeviceFixture()));
}

class UpdateDeviceFixture extends StatefulWidget {
  const UpdateDeviceFixture({super.key});

  @override
  State<UpdateDeviceFixture> createState() => _UpdateDeviceFixtureState();
}

class _UpdateDeviceFixtureState extends State<UpdateDeviceFixture> {
  String _output = 'Ready';

  Future<void> _run(String method) async {
    try {
      Object? result;
      if (method == 'database') {
        final db = openAppDatabase();
        try {
          final existing = await db
              .customSelect(
                "SELECT value_json FROM app_settings WHERE key = 'update.device.fixture'",
              )
              .get();
          if (existing.isEmpty) {
            final installed = await _channel.invokeMapMethod<String, Object?>(
              'getInstalledApp',
            );
            if (installed?['versionCode'] != 5) {
              throw StateError('Database marker was lost during upgrade');
            }
            await db.customStatement(
              "INSERT INTO app_settings (key,value_json,updated_at) VALUES ('update.device.fixture','synthetic-preserve-v5',1760000000)",
            );
          }
          result =
              (await db
                      .customSelect(
                        "SELECT key,value_json FROM app_settings WHERE key = 'update.device.fixture'",
                      )
                      .get())
                  .map((row) => row.data)
                  .toList();
        } finally {
          await db.close();
        }
      } else {
        final arguments = method == 'startDownload'
            ? jsonDecode(
                await File(
                  '/data/data/$_package/files/update-fixture.json',
                ).readAsString(),
              )
            : null;
        result = await _channel.invokeMethod<Object?>(method, arguments);
      }
      _output = '$method: ${jsonEncode(result)}';
    } catch (error) {
      _output = '$method: ERROR $error';
    }
    // adb logcat is the durable evidence, independent of screen truncation.
    debugPrint('UPDATER_DEVICE $_output');
    await File(
      '/data/data/$_package/files/update-device-result.txt',
    ).writeAsString(_output);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Updater device fixture')),
    body: ListView(
      children: [
        Wrap(
          children: [
            for (final method in [
              'getInstalledApp',
              'claimStartupCheck',
              'database',
              'startDownload',
              'queryDownload',
              'prepareInstall',
              'requestInstall',
              'openInstallSettings',
              'cancelDownload',
            ])
              Padding(
                padding: const EdgeInsets.all(4),
                child: ElevatedButton(
                  onPressed: () => _run(method),
                  child: Text(method),
                ),
              ),
          ],
        ),
        SelectableText(_output),
      ],
    ),
  );
}
