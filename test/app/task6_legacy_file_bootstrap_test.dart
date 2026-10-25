import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/data/app_database_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  final l10n = AppLocalizationsZh();

  testWidgets('production LazyDatabase bootstrap preserves a real v1 file', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('hoopito-task6-v1-'),
    ))!;
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}hooptrace.sqlite',
    );
    final raw = sqlite3.sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 1');
    raw.execute('CREATE TABLE legacy_sentinel(value TEXT NOT NULL)');
    raw.execute("INSERT INTO legacy_sentinel(value) VALUES ('untouched')");
    raw.close();
    final database = openAppDatabaseAt(file);
    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('legacy-bootstrap')));
    expect(find.byKey(const Key('legacy-bootstrap')), findsOneWidget);
    expect(find.text(l10n.legacyBootstrapHeadline), findsOneWidget);
    expect(find.text(l10n.legacyBootstrapBody(' v1')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(database.close);
    final verify = sqlite3.sqlite3.open(file.path);
    expect(verify.select('PRAGMA user_version').single.values.first, 1);
    expect(
      verify.select('SELECT value FROM legacy_sentinel').single.values.first,
      'untouched',
    );
    expect(
      verify
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name IN ('matches', 'match_events', 'active_sessions')",
          )
          .isEmpty,
      isTrue,
    );
    verify.close();
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for $finder');
}
