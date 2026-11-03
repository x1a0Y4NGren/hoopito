import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/test_helpers/continuous_series_journey.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'continuous matches complete on isolated Android with a real file database',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/series-integration-${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      final database = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.runAsync(database.close);
        if (await file.exists()) await file.delete();
      });
      await runContinuousSeriesJourney(tester, database);
    },
  );
}
