import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/audit/audit_log_entry.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/features/replay/widgets/replay_audit_sheet.dart';

import '../../test_helpers/test_database.dart';

void main() {
  testWidgets(
    'repository maps command audit actions and the sheet localizes them',
    (tester) async {
      final database = createTestDatabase();
      final repository = MatchRepository(database);
      await repository.createMinimalMatch(
        id: 'audit-match',
        redName: 'Red',
        blueName: 'Blue',
        createdAt: DateTime.utc(2026),
      );

      const actions = <String>[
        'locate',
        'possession',
        'possession_suggestion',
        'future_command_action',
      ];
      for (var index = 0; index < actions.length; index++) {
        await database
            .into(database.auditLogs)
            .insert(
              AuditLogsCompanion.insert(
                id: 'audit-$index',
                matchId: 'audit-match',
                targetId: 'target-$index',
                action: actions[index],
                beforeJson: jsonEncode(
                  index == 0 ? {'x': 0.1, 'y': 0.2} : {'side': 'red'},
                ),
                afterJson: jsonEncode(
                  index == 0 ? {'x': 0.3, 'y': 0.4} : {'side': 'blue'},
                ),
                createdAt: DateTime.utc(2026, 1, 1, 0, index),
              ),
            );
      }

      final logs = await repository.listAuditLogs('audit-match');

      expect(
        logs.map((log) => log.action),
        containsAll(<AuditAction>[
          AuditAction.locate,
          AuditAction.possession,
          AuditAction.possession_suggestion,
          AuditAction.unknown,
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Material(child: ReplayAuditSheet(logs: logs)),
        ),
      );

      expect(find.textContaining('定位'), findsOneWidget);
      expect(find.textContaining('球权'), findsNWidgets(2));
      expect(find.textContaining('locate'), findsNothing);
      expect(find.textContaining('possession'), findsNothing);
      expect(find.textContaining('possession_suggestion'), findsNothing);
      expect(find.textContaining('未知操作'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(child: ReplayAuditSheet(logs: logs)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Located'), findsOneWidget);
      expect(find.textContaining('Possession updated'), findsOneWidget);
      expect(find.textContaining('Possession suggested'), findsOneWidget);
      expect(find.textContaining('locate'), findsNothing);
      expect(find.textContaining('possession'), findsNothing);
      expect(find.textContaining('possession_suggestion'), findsNothing);
      expect(find.textContaining('Unknown operation'), findsOneWidget);
    },
  );
}
