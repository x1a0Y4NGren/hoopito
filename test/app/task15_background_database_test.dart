import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database_provider.dart';

void main() {
  test(
    'explicit file database opens through the production background executor',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hoopito-task15-db-',
      );
      final database = openAppDatabaseAt(
        File('${directory.path}${Platform.pathSeparator}hooptrace.sqlite'),
      );
      try {
        final result = await database
            .customSelect('SELECT 1 AS value')
            .getSingle();
        expect(result.read<int>('value'), 1);
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
