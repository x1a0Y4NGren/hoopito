import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';

import '../test_helpers/continuous_series_journey.dart';

void main() {
  testWidgets(
    'three games close into the group, replay individually, and reopen without starting another match',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase.inMemory();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.runAsync(database.close);
      });
      await runContinuousSeriesJourney(tester, database);
    },
  );
}
