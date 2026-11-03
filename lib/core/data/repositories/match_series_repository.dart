import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart' as db;
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/entities/match_series.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

class MatchSeriesRepository {
  MatchSeriesRepository(this.database);
  final db.AppDatabase database;

  Future<db.MatchSeriesRow?> _row(String id) => (database.select(
    database.matchSeries,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<MatchSeries?> getSeries(String id) =>
      database.transaction(() => _getSeries(id));

  Future<MatchSeries?> _getSeries(String id) async {
    final row = await _row(id);
    if (row == null) return null;
    final members =
        await (database.select(database.seriesMatches)
              ..where((t) => t.seriesId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.gameNumber)]))
            .get();
    final games = <SeriesGame>[];
    for (final member in members) {
      final detail = await MatchRepository(
        database,
      ).getMatchDetail(member.matchId);
      if (detail != null) {
        games.add(
          SeriesGame(
            matchId: member.matchId,
            gameNumber: member.gameNumber,
            slotASide: TeamSide.values.byName(member.slotASide),
            detail: detail,
          ),
        );
      }
    }
    return MatchSeries(
      id: row.id,
      slotAName: row.slotAName,
      slotBName: row.slotBName,
      slotAPlayerProfileId: row.slotAPlayerProfileId,
      slotBPlayerProfileId: row.slotBPlayerProfileId,
      isOpen: row.lifecycle == 'open',
      revision: row.revision,
      nextGameNumber: row.nextGameNumber,
      createdAt: row.createdAt,
      closedAt: row.closedAt,
      defaultSetup: jsonDecode(row.defaultSetupJson) as Map<String, dynamic>,
      games: List.unmodifiable(games),
    );
  }

  Stream<List<String>> _changes() => database
      .customSelect(
        'SELECT id FROM match_series ORDER BY created_at DESC, id',
        readsFrom: {
          database.matchSeries,
          database.seriesMatches,
          database.matches,
          database.matchParticipants,
          database.matchEvents,
          database.matchClocks,
          database.activeSessions,
          database.players,
        },
      )
      .watch()
      .map((rows) => rows.map((r) => r.read<String>('id')).toList());
  Stream<MatchSeries?> watchSeries(String id) =>
      _changes().asyncMap((_) => getSeries(id));
  Stream<List<MatchSeries>> watchSeriesList() => _changes().asyncMap(
    (_) => database.transaction(() async {
      final rows =
          await (database.select(database.matchSeries)..orderBy([
                (t) => OrderingTerm.desc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
              .get();
      return [
        for (final row in rows)
          if (await _getSeries(row.id) case final MatchSeries series) series,
      ];
    }),
  );
  Future<MatchSeries?> getOpenSeries() => database.transaction(() async {
    final row = await (database.select(
      database.matchSeries,
    )..where((t) => t.lifecycle.equals('open'))).getSingleOrNull();
    return row == null ? null : _getSeries(row.id);
  });

  Stream<MatchSeries?> watchOpenSeries() =>
      _changes().asyncMap((_) => getOpenSeries());
  Future<MatchSeries?> getForMatch(String matchId) =>
      database.transaction(() async {
        final row = await (database.select(
          database.seriesMatches,
        )..where((t) => t.matchId.equals(matchId))).getSingleOrNull();
        return row == null ? null : _getSeries(row.seriesId);
      });

  Future<void> close({
    required String seriesId,
    required int expectedRevision,
    required String intentId,
    DateTime? at,
  }) => _lifecycle(seriesId, expectedRevision, intentId, false, at);
  Future<void> reopen({
    required String seriesId,
    required int expectedRevision,
    required String intentId,
    DateTime? at,
  }) => _lifecycle(seriesId, expectedRevision, intentId, true, at);
  Future<void> _lifecycle(
    String id,
    int revision,
    String intent,
    bool reopen,
    DateTime? at,
  ) => database.transaction(() async {
    final row = await _row(id);
    if (row == null) throw const SeriesFailure('missing');
    final intents =
        jsonDecode(row.lifecycleIntentsJson) as Map<String, dynamic>;
    final fingerprint = jsonEncode([id, revision, reopen]);
    if (intents.containsKey(intent)) {
      if ((intents[intent] as Map)['fingerprint'] != fingerprint) {
        throw const SeriesFailure('intentConflict');
      }
      return;
    }
    if (intent.trim().isEmpty) throw const SeriesFailure('invalidIntent');
    if (row.revision != revision || (row.lifecycle == 'open') == reopen) {
      throw const SeriesFailure('stale');
    }
    if (await database.select(database.activeSessions).getSingleOrNull() !=
            null ||
        await (database.select(
              database.matches,
            )..where((t) => t.lifecycle.equals('active'))).getSingleOrNull() !=
            null) {
      throw const SeriesFailure('activeMatch');
    }
    if (reopen && await getOpenSeries() != null) {
      throw const SeriesFailure('openSeries');
    }
    intents[intent] = {'fingerprint': fingerprint, 'revision': revision + 1};
    await (database.update(
      database.matchSeries,
    )..where((t) => t.id.equals(id))).write(
      db.MatchSeriesCompanion(
        lifecycle: Value(reopen ? 'open' : 'closed'),
        closedAt: Value(reopen ? null : (at ?? DateTime.now()).toUtc()),
        revision: Value(revision + 1),
        lifecycleIntentsJson: Value(jsonEncode(intents)),
      ),
    );
  });

  Future<void> validateStart(StartMatchCommand command) async {
    final context = command.seriesContext;
    final open = await (database.select(
      database.matchSeries,
    )..where((t) => t.lifecycle.equals('open'))).getSingleOrNull();
    if (context == null) {
      if (open != null) throw const SeriesFailure('openSeries');
      return;
    }
    if (context.create) {
      if (open != null || await _row(context.seriesId) != null) {
        throw const SeriesFailure('openSeries');
      }
      if (context.expectedRevision != 0 ||
          context.gameNumber != 1 ||
          context.seriesId.trim().isEmpty) {
        throw const SeriesFailure('stale');
      }
      return;
    }
    if (open == null ||
        open.id != context.seriesId ||
        open.revision != context.expectedRevision ||
        open.nextGameNumber != context.gameNumber) {
      throw const SeriesFailure('stale');
    }
    final aRed = context.slotASide == TeamSide.red;
    if ((aRed ? command.redName : command.blueName).trim() != open.slotAName ||
        (aRed ? command.blueName : command.redName).trim() != open.slotBName ||
        (aRed ? command.redPlayerProfileId : command.bluePlayerProfileId) !=
            open.slotAPlayerProfileId ||
        (aRed ? command.bluePlayerProfileId : command.redPlayerProfileId) !=
            open.slotBPlayerProfileId) {
      throw const SeriesFailure('pairChanged');
    }
  }

  /// Called only within the start command transaction, after validation.
  Future<void> attachStart(StartMatchCommand command) async {
    final context = command.seriesContext;
    if (context == null) return;
    final setup = jsonEncode({
      'ruleTemplate': command.payload['ruleTemplate'],
      'clockMode': command.clockMode.name,
      'regulationSeconds': command.clockMode == ClockMode.countdown
          ? command.regulationSeconds
          : null,
      'timerEnabled': command.timerEnabled,
      'slotASide': context.slotASide.name,
    });
    if (context.create) {
      final aRed = context.slotASide == TeamSide.red;
      await database
          .into(database.matchSeries)
          .insert(
            db.MatchSeriesCompanion.insert(
              id: context.seriesId,
              slotAName: (aRed ? command.redName : command.blueName).trim(),
              slotBName: (aRed ? command.blueName : command.redName).trim(),
              slotAPlayerProfileId: Value(
                aRed ? command.redPlayerProfileId : command.bluePlayerProfileId,
              ),
              slotBPlayerProfileId: Value(
                aRed ? command.bluePlayerProfileId : command.redPlayerProfileId,
              ),
              createdAt: command.createdAt,
              defaultSetupJson: setup,
            ),
          );
    }
    await database
        .into(database.seriesMatches)
        .insert(
          db.SeriesMatchesCompanion.insert(
            matchId: command.matchId,
            seriesId: context.seriesId,
            gameNumber: context.gameNumber,
            slotASide: context.slotASide.name,
          ),
        );
    await (database.update(
      database.matchSeries,
    )..where((t) => t.id.equals(context.seriesId))).write(
      db.MatchSeriesCompanion(
        nextGameNumber: Value(context.gameNumber + 1),
        revision: Value(context.expectedRevision + 1),
        defaultSetupJson: Value(setup),
      ),
    );
  }

  Future<StartMatchCommand> prepareNext(
    String seriesId, {
    bool swapSides = false,
  }) async {
    final series = await getSeries(seriesId);
    if (series == null || !series.isOpen) throw const SeriesFailure('closed');
    final setup = series.defaultSetup;
    final r = setup['ruleTemplate'] as Map<String, dynamic>;
    final previous = TeamSide.values.byName(setup['slotASide'] as String);
    final side = swapSides
        ? (previous == TeamSide.red ? TeamSide.blue : TeamSide.red)
        : previous;
    final aRed = side == TeamSide.red;
    return StartMatchCommand(
      redName: aRed ? series.slotAName : series.slotBName,
      blueName: aRed ? series.slotBName : series.slotAName,
      redPlayerProfileId: aRed
          ? series.slotAPlayerProfileId
          : series.slotBPlayerProfileId,
      bluePlayerProfileId: aRed
          ? series.slotBPlayerProfileId
          : series.slotAPlayerProfileId,
      ruleTemplate: RuleTemplate(
        id: r['id'] as String,
        name: r['name'] as String,
        scoreButtons: (r['scoreButtons'] as List).cast<int>(),
        targetScore: r['targetScore'] as int?,
        timeLimitSeconds: r['timeLimitSeconds'] as int?,
        winByTwo: r['winByTwo'] as bool? ?? false,
        foulLimit: r['foulLimit'] as int?,
        possessionHintEnabled: r['possessionHintEnabled'] as bool? ?? false,
        possessionPolicy: PossessionPolicy.values.byName(
          r['possessionPolicy'] as String? ?? 'manual',
        ),
        customEventTypes: (r['customEventTypes'] as List? ?? []).cast<String>(),
      ),
      recordingMode: RecordingMode.simple,
      clockMode: ClockMode.values.byName(setup['clockMode'] as String),
      regulationSeconds: setup['regulationSeconds'] as int?,
      timerEnabled: setup['timerEnabled'] as bool,
      seriesContext: SeriesStartContext(
        seriesId: series.id,
        expectedRevision: series.revision,
        gameNumber: series.nextGameNumber,
        slotASide: side,
      ),
    );
  }
}
