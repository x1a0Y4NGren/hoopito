import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/audit/audit_diff.dart';
import 'package:hoopito/core/audit/audit_log_entry.dart';

void main() {
  test('audit entry stores before and after values', () {
    final entry = AuditLogEntry(
      id: 'audit-1',
      matchId: 'match-1',
      targetId: 'event-1',
      action: AuditAction.edit,
      createdAt: DateTime.utc(2026),
      diff: const AuditDiff(before: {'points': 2}, after: {'points': 3}),
    );

    expect(entry.diff.before['points'], 2);
    expect(entry.diff.after['points'], 3);
    expect(entry.action, AuditAction.edit);
  });
}
