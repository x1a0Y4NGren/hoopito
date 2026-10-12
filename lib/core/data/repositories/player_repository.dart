import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

class PlayerRepository {
  PlayerRepository(this._database);

  final AppDatabase _database;

  Future<void> save(Player player) {
    return _database
        .into(_database.players)
        .insertOnConflictUpdate(
          PlayersCompanion.insert(
            id: player.id,
            nickname: player.nickname,
            createdAt: player.createdAt,
            preferredSide: Value(player.preferredSide?.name),
            note: Value(player.note),
          ),
        );
  }

  Future<Player?> getById(String id) async {
    final query = _database.select(_database.players)
      ..where((player) => player.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  Future<void> delete(String id) async {
    await (_database.delete(
      _database.players,
    )..where((player) => player.id.equals(id))).go();
  }

  Stream<List<Player>> watchAll() {
    final query = _database.select(_database.players)
      ..orderBy([(player) => OrderingTerm.asc(player.createdAt)]);

    return query.watch().map(
      (rows) => rows.map(_mapRow).toList(growable: false),
    );
  }

  static Player _mapRow(PlayerRow row) {
    return Player(
      id: row.id,
      nickname: row.nickname,
      createdAt: row.createdAt,
      preferredSide: row.preferredSide == null
          ? null
          : TeamSide.values.byName(row.preferredSide!),
      note: row.note,
    );
  }
}
