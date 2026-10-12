import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

/// Owns history-only lifecycle operations that are deliberately separate from
/// the live command kernel. Archive is reversible organization; permanent
/// deletion is an explicit, terminal user action.
class MatchLifecycleRepository {
  MatchLifecycleRepository(this._database);

  final AppDatabase _database;

  Future<void> archive(String matchId) async {
    await _transition(
      matchId,
      from: MatchLifecycle.finished,
      to: MatchLifecycle.archived,
    );
  }

  Future<void> unarchive(String matchId) async {
    await _transition(
      matchId,
      from: MatchLifecycle.archived,
      to: MatchLifecycle.finished,
    );
  }

  Future<void> permanentlyDelete(
    String matchId, {
    required bool confirmed,
  }) async {
    if (!confirmed) {
      throw ArgumentError('Permanent match deletion requires confirmation.');
    }
    await _database.transaction(() async {
      final row = await (_database.select(
        _database.matches,
      )..where((match) => match.id.equals(matchId))).getSingleOrNull();
      if (row == null) {
        throw StateError('Cannot delete missing match $matchId.');
      }
      final lifecycle = MatchLifecycle.values.byName(row.lifecycle);
      if (lifecycle != MatchLifecycle.finished &&
          lifecycle != MatchLifecycle.archived) {
        throw StateError('Only completed matches can be permanently deleted.');
      }
      // All dependent match graph tables use ON DELETE CASCADE (or SET NULL
      // for the optional possession boundary and profile link), so one
      // statement preserves atomicity and removes the complete history.
      await (_database.delete(
        _database.matches,
      )..where((match) => match.id.equals(matchId))).go();
    });
  }

  Future<void> _transition(
    String matchId, {
    required MatchLifecycle from,
    required MatchLifecycle to,
  }) async {
    await _database.transaction(() async {
      final row = await (_database.select(
        _database.matches,
      )..where((match) => match.id.equals(matchId))).getSingleOrNull();
      if (row == null) {
        throw StateError('Cannot update missing match $matchId.');
      }
      final lifecycle = MatchLifecycle.values.byName(row.lifecycle);
      if (lifecycle != from) {
        throw StateError(
          'Cannot transition match $matchId from ${lifecycle.name} to ${to.name}.',
        );
      }
      await (_database.update(_database.matches)
            ..where((match) => match.id.equals(matchId)))
          .write(MatchesCompanion(lifecycle: Value(to.name)));
    });
  }
}
