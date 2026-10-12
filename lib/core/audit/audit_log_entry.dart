import 'package:hoopito/core/audit/audit_diff.dart';

/// Typed names for the action values persisted in the audit log.
///
/// Command-backed writes predate this model and use the snake-case
/// `possession_suggestion` value directly. Keep that spelling here so
/// repository reads, backup validation, and audit presentation all share the
/// same lossless storage contract.
enum AuditAction {
  create,
  undo,
  edit,
  delete,
  import,
  restore,
  command,
  locate,
  possession,
  // The persisted command action is intentionally snake-case.
  // ignore: constant_identifier_names
  possession_suggestion,
  unknown;

  /// Decodes persisted action names without allowing one bad row to break
  /// the entire audit history screen.
  static AuditAction fromStorage(String raw) {
    for (final action in values) {
      if (action.name == raw) return action;
    }
    return AuditAction.unknown;
  }
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.matchId,
    required this.targetId,
    required this.action,
    required this.createdAt,
    required this.diff,
    this.reason,
  });

  final String id;
  final String matchId;
  final String targetId;
  final AuditAction action;
  final DateTime createdAt;
  final AuditDiff diff;
  final String? reason;
}
