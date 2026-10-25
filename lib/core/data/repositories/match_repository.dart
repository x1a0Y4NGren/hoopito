import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/audit/audit_diff.dart';
import 'package:hoopito/core/audit/audit_log_entry.dart';
import 'package:hoopito/core/domain/entities/match.dart' as domain_match;
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/match_history_entry.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/entities/shot_location.dart' as domain;
import 'package:hoopito/core/domain/entities/possession_segment.dart'
    as domain_possession;
import 'package:hoopito/core/domain/entities/active_session.dart'
    as domain_session;
import 'package:hoopito/core/domain/entities/clock_state.dart';
import 'package:hoopito/core/domain/clock/clock_engine.dart';
import 'package:hoopito/core/domain/scoring/scoring_reducer.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:uuid/uuid.dart';

class MatchRepository {
  MatchRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<void> createMinimalMatch({
    required String id,
    required String redName,
    required String blueName,
    required DateTime createdAt,
  }) {
    return saveMatch(
      domain_match.Match(
        id: id,
        redName: redName,
        blueName: blueName,
        status: domain_match.MatchStatus.active,
        ruleTemplateSnapshot: const RuleTemplate(
          id: 'free',
          name: 'Free scoring',
          scoreButtons: [1, 2, 3],
        ),
        createdAt: createdAt,
      ),
    );
  }

  Future<void> saveMatch(domain_match.Match match) {
    return _database.transaction(() async {
      await _database
          .into(_database.matches)
          .insertOnConflictUpdate(
            MatchesCompanion.insert(
              id: match.id,
              lifecycle: Value(match.lifecycle.name),
              recordingMode: Value(match.recordingMode.name),
              trackingCoverage: Value(match.trackingCoverage.name),
              ruleTemplateJson: jsonEncode(
                _ruleTemplateToJson(match.ruleTemplateSnapshot),
              ),
              createdAt: match.createdAt,
              startedAt: Value(match.startedAt),
              endedAt: Value(match.endedAt),
              timerEnabled: Value(match.timerEnabled),
              note: Value(match.note),
            ),
          );

      // Participant rows are the sole canonical ownership projection.
      await (_database.delete(
        _database.matchParticipants,
      )..where((participant) => participant.matchId.equals(match.id))).go();
      for (final participant in match.participants) {
        await _database
            .into(_database.matchParticipants)
            .insert(
              MatchParticipantsCompanion.insert(
                id: participant.id,
                matchId: participant.matchId,
                side: participant.side.name,
                nameSnapshot: participant.nameSnapshot,
                playerProfileId: Value(participant.playerProfileId),
              ),
            );
      }
    });
  }

  Future<void> addEvent(MatchEvent event) => saveEvent(event);

  Future<void> saveEvent(MatchEvent event) {
    return _database
        .into(_database.matchEvents)
        .insertOnConflictUpdate(_eventCompanion(event));
  }

  Future<void> saveShotLocation(domain.ShotLocation location) {
    return _database
        .into(_database.shotLocations)
        .insertOnConflictUpdate(_shotLocationCompanion(location));
  }

  Future<void> saveEventWithShotLocation(
    MatchEvent event, {
    domain.ShotLocation? shotLocation,
  }) {
    if (shotLocation != null &&
        (shotLocation.matchId != event.matchId ||
            shotLocation.eventId != event.id)) {
      throw ArgumentError(
        'Shot location must reference the event and match being saved.',
      );
    }

    return _database.transaction(() async {
      await saveEvent(event);
      if (shotLocation != null) {
        await saveShotLocation(shotLocation);
      }
    });
  }

  /// Legacy v0.1 full-snapshot synchronization path.
  ///
  /// New live scoring must use [MatchCommandService]. This method remains
  /// only for compatibility with the pre-1.0 coordinator and is deliberately
  /// not used by the command kernel.
  @Deprecated('Use MatchCommandService commands instead.')
  Future<void> replaceMatchSnapshot(
    String matchId, {
    required List<MatchEvent> events,
    required List<domain.ShotLocation> shotLocations,
  }) {
    final eventIds = <String>{};
    for (final event in events) {
      if (event.matchId != matchId) {
        throw ArgumentError(
          'Event ${event.id} does not belong to match $matchId.',
        );
      }
      if (!eventIds.add(event.id)) {
        throw ArgumentError('Duplicate event id ${event.id} in snapshot.');
      }
    }

    final locationIds = <String>{};
    for (final location in shotLocations) {
      if (location.matchId != matchId) {
        throw ArgumentError(
          'Shot location ${location.id} does not belong to match $matchId.',
        );
      }
      if (!eventIds.contains(location.eventId)) {
        throw ArgumentError(
          'Shot location ${location.id} references an event outside the '
          'snapshot.',
        );
      }
      if (!locationIds.add(location.id)) {
        throw ArgumentError(
          'Duplicate shot location id ${location.id} in snapshot.',
        );
      }
    }

    return _database.transaction(() async {
      await (_database.delete(
        _database.shotLocations,
      )..where((location) => location.matchId.equals(matchId))).go();
      await (_database.delete(
        _database.matchEvents,
      )..where((event) => event.matchId.equals(matchId))).go();
      for (final event in events) {
        await _database
            .into(_database.matchEvents)
            .insert(_eventCompanion(event));
      }
      for (final location in shotLocations) {
        await _database
            .into(_database.shotLocations)
            .insert(_shotLocationCompanion(location));
      }
    });
  }

  Future<void> finishMatch(String matchId, {required DateTime endedAt}) async {
    final updated =
        await (_database.update(
          _database.matches,
        )..where((match) => match.id.equals(matchId))).write(
          MatchesCompanion(
            lifecycle: Value(domain_match.MatchLifecycle.finished.name),
            endedAt: Value(endedAt),
          ),
        );
    if (updated == 0) {
      throw StateError('Cannot finish missing match $matchId.');
    }
  }

  Future<void> moveShotLocation({
    required String locationId,
    required CourtPoint point,
    String? reason,
  }) {
    return _database.transaction(() async {
      final query = _database.select(_database.shotLocations)
        ..where((location) => location.id.equals(locationId));
      final before = await query.getSingleOrNull();
      if (before == null) {
        throw StateError('Missing shot location $locationId.');
      }
      if (!before.isConfirmed) {
        throw StateError('Only confirmed shot locations can be moved.');
      }
      await (_database.update(_database.shotLocations)
            ..where((location) => location.id.equals(locationId)))
          .write(ShotLocationsCompanion(x: Value(point.x), y: Value(point.y)));
      await _writeAudit(
        matchId: before.matchId,
        targetId: locationId,
        action: AuditAction.edit,
        before: _locationJson(before),
        after: {..._locationJson(before), ...point.toJson()},
        reason: reason,
      );
    });
  }

  Future<void> softDeleteEvent({required String eventId, String? reason}) {
    return _database.transaction(() async {
      final before = await _eventRow(eventId);
      if (before == null) throw StateError('Missing event $eventId.');
      if (before.isDeleted) return;
      await (_database.update(_database.matchEvents)
            ..where((event) => event.id.equals(eventId)))
          .write(const MatchEventsCompanion(isDeleted: Value(true)));
      await _writeAudit(
        matchId: before.matchId,
        targetId: eventId,
        action: AuditAction.delete,
        before: _eventJson(before),
        after: {..._eventJson(before), 'isDeleted': true},
        reason: reason,
      );
    });
  }

  Future<void> updateEventNote({
    required String eventId,
    required String note,
    String? reason,
  }) {
    return _database.transaction(() async {
      final before = await _eventRow(eventId);
      if (before == null) throw StateError('Missing event $eventId.');
      await (_database.update(_database.matchEvents)
            ..where((event) => event.id.equals(eventId)))
          .write(MatchEventsCompanion(note: Value(note.trim())));
      await _writeAudit(
        matchId: before.matchId,
        targetId: eventId,
        action: AuditAction.edit,
        before: _eventJson(before),
        after: {..._eventJson(before), 'note': note.trim()},
        reason: reason,
      );
    });
  }

  Future<List<AuditLogEntry>> listAuditLogs(String matchId) async {
    final query = _database.select(_database.auditLogs)
      ..where(
        (log) => log.matchId.equals(matchId) & log.action.isNotIn(['command']),
      )
      ..orderBy([
        (log) => OrderingTerm.desc(log.createdAt),
        (_) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
      ]);
    return (await query.get())
        .map(
          (row) => AuditLogEntry(
            id: row.id,
            matchId: row.matchId,
            targetId: row.targetId,
            action: AuditAction.fromStorage(row.action),
            createdAt: row.createdAt.toUtc(),
            reason: row.reason,
            diff: AuditDiff(
              before: (jsonDecode(row.beforeJson) as Map)
                  .cast<String, Object?>(),
              after: (jsonDecode(row.afterJson) as Map).cast<String, Object?>(),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<MatchEventRow?> _eventRow(String eventId) {
    final query = _database.select(_database.matchEvents)
      ..where((event) => event.id.equals(eventId));
    return query.getSingleOrNull();
  }

  Future<void> _writeAudit({
    required String matchId,
    required String targetId,
    required AuditAction action,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    String? reason,
  }) {
    return _database
        .into(_database.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            id: _uuid.v4(),
            matchId: matchId,
            targetId: targetId,
            action: action.name,
            beforeJson: jsonEncode(before),
            afterJson: jsonEncode(after),
            reason: Value(_normalizeReason(reason)),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  static String? _normalizeReason(String? reason) {
    final value = reason?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Map<String, Object?> _eventJson(MatchEventRow row) => {
    'id': row.id,
    'matchId': row.matchId,
    'type': row.type,
    'side': row.side,
    'points': row.points,
    'occurredAt': row.occurredAt.toUtc().toIso8601String(),
    'note': row.note,
    'customLabel': row.customLabel,
    'outcome': row.outcome,
    'matchClockPositionSeconds': row.matchClockPositionSeconds,
    'isDeleted': row.isDeleted,
  };

  static Map<String, Object?> _locationJson(ShotLocation row) => {
    'id': row.id,
    'matchId': row.matchId,
    'eventId': row.eventId,
    'x': row.x,
    'y': row.y,
    'isConfirmed': row.isConfirmed,
  };

  Stream<List<MatchEvent>> watchEvents(String matchId) {
    final query = _database.select(_database.matchEvents)
      ..where((event) => event.matchId.equals(matchId))
      ..orderBy([
        (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
      ]);

    return query.watch().map((rows) {
      return rows.map(mapEventRow).toList();
    });
  }

  Future<MatchDetail?> getMatchDetail(String matchId) {
    return _database.transaction(() async {
      final matchQuery = _database.select(_database.matches)
        ..where((match) => match.id.equals(matchId));
      final matchRow = await matchQuery.getSingleOrNull();
      if (matchRow == null) {
        return null;
      }

      final eventQuery = _database.select(_database.matchEvents)
        ..where((event) => event.matchId.equals(matchId))
        ..orderBy([
          (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
        ]);
      final locationQuery = _database.select(_database.shotLocations)
        ..where((location) => location.matchId.equals(matchId));
      final participantQuery = _database.select(_database.matchParticipants)
        ..where((participant) => participant.matchId.equals(matchId));
      final possessionQuery = _database.select(_database.possessionSegments)
        ..where((segment) => segment.matchId.equals(matchId))
        ..orderBy([
          (_) => OrderingTerm.asc(const CustomExpression<int>('rowid')),
        ]);
      final eventRows = await eventQuery.get();
      final locationRows = await locationQuery.get();
      final participantRows = await participantQuery.get();
      final possessionRows = await possessionQuery.get();
      final activeRow = await (_database.select(
        _database.activeSessions,
      )..where((session) => session.matchId.equals(matchId))).getSingleOrNull();
      final clockRow = await (_database.select(
        _database.matchClocks,
      )..where((clock) => clock.matchId.equals(matchId))).getSingleOrNull();

      return buildDetail(
        matchRow,
        eventRows,
        locationRows,
        participantRows: participantRows,
        possessionRows: possessionRows,
        activeSession: activeRow == null
            ? null
            : domain_session.ActiveSession(
                id: activeRow.id,
                matchId: activeRow.matchId,
                claimedAtUtc: activeRow.claimedAtUtc.toUtc(),
              ),
        clock: clockRow == null ? null : _projectClock(clockRow),
      );
    });
  }

  /// Emits the single active match and rebuilds its committed projection when
  /// any table that contributes to that projection changes. The explicit
  /// [readsFrom] set is intentional: a query that only selected
  /// [activeSessions] would otherwise miss score, location, participant and
  /// clock writes after process reconstruction.
  Stream<MatchDetail?> watchActiveMatch() {
    final query = _database.customSelect(
      'SELECT active_sessions.match_id AS match_id '
      'FROM active_sessions '
      'JOIN matches ON matches.id = active_sessions.match_id '
      "WHERE active_sessions.id = 'active' LIMIT 1",
      readsFrom: {
        _database.activeSessions,
        _database.matches,
        _database.matchParticipants,
        _database.matchEvents,
        _database.shotLocations,
        _database.possessionSegments,
        _database.matchClocks,
      },
    );
    // Drift's watched query emits its current result immediately and then
    // emits again when any table in [readsFrom] changes. Keep that single
    // source of initial state; a second manual getActiveMatch() emission here
    // races the watched query and makes consumers observe duplicate starts.
    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      return getMatchDetail(rows.single.read<String>('match_id'));
    });
  }

  /// Reactive detail stream for a live scoring route. It tracks the same
  /// complete projection graph as [watchActiveMatch], but is addressable by
  /// match id so a route can be rebuilt without retaining a controller.
  Stream<MatchDetail?> watchLiveMatch(String matchId) {
    final query = _database.customSelect(
      'SELECT id FROM matches WHERE id = ? LIMIT 1',
      variables: [Variable.withString(matchId)],
      readsFrom: {
        _database.matches,
        _database.matchParticipants,
        _database.matchEvents,
        _database.shotLocations,
        _database.possessionSegments,
        _database.matchClocks,
        _database.activeSessions,
      },
    );
    // As above, query.watch() supplies the one initial snapshot and all later
    // projection updates. Do not prepend a second imperative read.
    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      return getMatchDetail(matchId);
    });
  }

  Stream<MatchDetail?> watchMatchDetail(String matchId) =>
      watchLiveMatch(matchId);

  Future<MatchDetail?> getActiveMatch() async {
    final row = await (_database.select(
      _database.activeSessions,
    )..where((session) => session.id.equals('active'))).getSingleOrNull();
    if (row == null) return null;
    return getMatchDetail(row.matchId);
  }

  /// Loads one bounded history page with a single aggregate projection query.
  ///
  /// The query deliberately does not call [getMatchDetail] for each row. All
  /// score, attempt, location, participant, and profile values are projected
  /// by grouped subqueries and joins, which keeps the first page O(page size)
  /// in both returned data and Dart-side work.
  Future<MatchHistoryPage> queryHistory({
    MatchHistoryFilter filter = const MatchHistoryFilter(),
    int offset = 0,
    int limit = 20,
  }) async {
    final spec = _historyQuerySpec(
      filter: filter,
      offset: offset,
      limit: limit,
    );
    if (spec.empty) {
      return MatchHistoryPage(
        entries: const [],
        offset: offset,
        limit: limit,
        hasMore: false,
      );
    }
    await _database.ensureSchemaIndexes();
    final rows = await _database
        .customSelect(
          spec.sql,
          variables: spec.variables,
          readsFrom: _historyReadsFrom,
        )
        .get();
    return _mapHistoryPage(rows, offset: offset, limit: limit);
  }

  /// Loads the bounded recovery projection for unfinished matches imported
  /// from a backup. Keeping this named entry point beside [queryHistory]
  /// prevents callers from accidentally exposing ordinary abandoned matches.
  Future<MatchHistoryPage> queryImportedIncomplete({
    int offset = 0,
    int limit = 20,
  }) => queryHistory(
    filter: const MatchHistoryFilter(importedIncomplete: true),
    offset: offset,
    limit: limit,
  );

  /// Alias kept intentionally descriptive for callers that prefer list/page
  /// terminology over query terminology.
  Future<MatchHistoryPage> listHistoryPage({
    MatchHistoryFilter filter = const MatchHistoryFilter(),
    int offset = 0,
    int limit = 20,
  }) => queryHistory(filter: filter, offset: offset, limit: limit);

  /// Legacy all-history API. New screens should use [queryHistory] so the
  /// result remains bounded. This wrapper walks bounded pages without opening
  /// a detail query per match.
  Future<List<MatchHistoryEntry>> listHistory({
    MatchHistoryFilter filter = const MatchHistoryFilter(),
  }) async {
    const pageSize = 100;
    final entries = <MatchHistoryEntry>[];
    var offset = 0;
    while (true) {
      final page = await queryHistory(
        filter: filter,
        offset: offset,
        limit: pageSize,
      );
      entries.addAll(page.entries);
      if (!page.hasMore) return List.unmodifiable(entries);
      offset = page.nextOffset!;
    }
  }

  Stream<MatchHistoryPage> watchHistoryPage({
    MatchHistoryFilter filter = const MatchHistoryFilter(),
    int offset = 0,
    int limit = 20,
  }) {
    final spec = _historyQuerySpec(
      filter: filter,
      offset: offset,
      limit: limit,
    );
    if (spec.empty) {
      return Stream.value(
        MatchHistoryPage(
          entries: const [],
          offset: offset,
          limit: limit,
          hasMore: false,
        ),
      );
    }
    return Stream.fromFuture(_database.ensureSchemaIndexes()).asyncExpand((_) {
      final query = _database.customSelect(
        spec.sql,
        variables: spec.variables,
        readsFrom: _historyReadsFrom,
      );
      return query.watch().map(
        (rows) => _mapHistoryPage(rows, offset: offset, limit: limit),
      );
    });
  }

  Stream<List<MatchHistoryEntry>> watchHistory({
    MatchHistoryFilter filter = const MatchHistoryFilter(),
  }) =>
      watchHistoryPage(filter: filter, limit: 100).map((page) => page.entries);

  /// Invalidates retained history pages without querying or hydrating rows.
  Stream<void> watchHistoryChanges() => _database
      .tableUpdates(TableUpdateQuery.onAllTables(_historyReadsFrom))
      .map<void>((_) {});

  Set<TableInfo> get _historyReadsFrom => {
    _database.matches,
    _database.matchParticipants,
    _database.players,
    _database.matchEvents,
    _database.shotLocations,
  };

  _HistoryQuerySpec _historyQuerySpec({
    required MatchHistoryFilter filter,
    required int offset,
    required int limit,
  }) {
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 100');
    }

    final variables = <Variable<Object>>[];
    final conditions = <String>['m.lifecycle != ?'];
    variables.add(Variable.withString(domain_match.MatchLifecycle.active.name));

    // History is a public completed-match projection. Draft/active/abandoned
    // rows are owned by pregame, recovery, and discard flows respectively and
    // must remain invisible even when a caller supplies an explicit lifecycle
    // filter. Imported unfinished rows are the one deliberate exception: the
    // recovery projection opts into them with a reserved note marker.
    var lifecycles = filter.selectedLifecycles
        .where(
          (lifecycle) => filter.importedIncomplete
              ? lifecycle == domain_match.MatchLifecycle.abandoned
              : lifecycle == domain_match.MatchLifecycle.finished ||
                    lifecycle == domain_match.MatchLifecycle.archived,
        )
        .toSet();
    if (filter.importedIncomplete) {
      conditions.add('(m.note = ? OR m.note LIKE ?)');
      variables.add(Variable.withString(importedIncompleteNoteMarker));
      variables.add(Variable.withString('% [$importedIncompleteNoteMarker]'));
    } else if (filter.archived == true) {
      lifecycles = {domain_match.MatchLifecycle.archived};
    } else if (filter.archived == false) {
      lifecycles = lifecycles
          .where(
            (lifecycle) => lifecycle != domain_match.MatchLifecycle.archived,
          )
          .toSet();
    }
    if (lifecycles.isEmpty) {
      return const _HistoryQuerySpec.empty();
    }

    final lifecycleNames = lifecycles
        .map((lifecycle) {
          variables.add(Variable.withString(lifecycle.name));
          return '?';
        })
        .join(', ');
    conditions.add('m.lifecycle IN ($lifecycleNames)');

    final search = filter.search?.trim().toLowerCase();
    if (search != null && search.isNotEmpty) {
      final pattern = '%$search%';
      conditions.add('''(
        lower(COALESCE(red.name_snapshot, '')) LIKE ? OR
        lower(COALESCE(blue.name_snapshot, '')) LIKE ? OR
        lower(COALESCE(red.player_profile_id, '')) LIKE ? OR
        lower(COALESCE(blue.player_profile_id, '')) LIKE ? OR
        lower(COALESCE(red_player.nickname, '')) LIKE ? OR
        lower(COALESCE(blue_player.nickname, '')) LIKE ?
      )''');
      for (var index = 0; index < 6; index++) {
        variables.add(Variable.withString(pattern));
      }
    }
    if (filter.playerProfileId != null &&
        filter.playerProfileId!.trim().isNotEmpty) {
      conditions.add('''(
        red.player_profile_id = ? OR blue.player_profile_id = ?
      )''');
      variables.add(Variable.withString(filter.playerProfileId!.trim()));
      variables.add(Variable.withString(filter.playerProfileId!.trim()));
    }
    if (filter.from != null) {
      conditions.add('COALESCE(m.started_at, m.created_at) >= ?');
      variables.add(Variable.withDateTime(filter.from!.toUtc()));
    }
    if (filter.to != null) {
      conditions.add('COALESCE(m.started_at, m.created_at) < ?');
      variables.add(Variable.withDateTime(filter.to!.toUtc()));
    }
    if (filter.ruleId != null && filter.ruleId!.trim().isNotEmpty) {
      conditions.add("json_extract(m.rule_template_json, '\$.id') = ?");
      variables.add(Variable.withString(filter.ruleId!.trim()));
    }
    if (filter.ruleName != null && filter.ruleName!.trim().isNotEmpty) {
      conditions.add("json_extract(m.rule_template_json, '\$.name') = ?");
      variables.add(Variable.withString(filter.ruleName!.trim()));
    }
    if (filter.recordingMode != null) {
      conditions.add('m.recording_mode = ?');
      variables.add(Variable.withString(filter.recordingMode!.name));
    }

    variables.add(Variable.withInt(limit + 1));
    variables.add(Variable.withInt(offset));
    return _HistoryQuerySpec(
      sql:
          '''
        WITH candidates AS (
          SELECT
            m.id AS match_id,
            COALESCE(m.started_at, m.created_at) AS played_at,
            m.started_at AS started_at,
            m.created_at AS created_at,
            m.ended_at AS ended_at,
            m.note AS note,
            m.lifecycle AS lifecycle,
            m.recording_mode AS recording_mode,
            m.tracking_coverage AS tracking_coverage,
            m.rule_template_json AS rule_json,
            red.name_snapshot AS red_name,
            red.player_profile_id AS red_profile_id,
            red_player.nickname AS red_profile_nickname,
            blue.name_snapshot AS blue_name,
            blue.player_profile_id AS blue_profile_id,
            blue_player.nickname AS blue_profile_nickname
          FROM matches m
          LEFT JOIN match_participants red
            ON red.match_id = m.id AND red.side = 'red'
          LEFT JOIN match_participants blue
            ON blue.match_id = m.id AND blue.side = 'blue'
          LEFT JOIN players red_player ON red_player.id = red.player_profile_id
          LEFT JOIN players blue_player ON blue_player.id = blue.player_profile_id
          WHERE ${conditions.join('\n            AND ')}
          ORDER BY played_at DESC, m.id DESC
          LIMIT ? OFFSET ?
        ),
        scores AS (
          SELECT
            e.match_id,
            SUM(CASE WHEN e.is_deleted = 0 AND e.side = 'red' AND (
              e.type = 'score' OR
              ((e.type = 'fieldGoal' OR e.type = 'freeThrow') AND e.outcome = 'made')
            ) THEN e.points ELSE 0 END) AS red_score,
            SUM(CASE WHEN e.is_deleted = 0 AND e.side = 'blue' AND (
              e.type = 'score' OR
              ((e.type = 'fieldGoal' OR e.type = 'freeThrow') AND e.outcome = 'made')
            ) THEN e.points ELSE 0 END) AS blue_score
          FROM match_events e
          INNER JOIN candidates c ON c.match_id = e.match_id
          GROUP BY e.match_id
        ),
        attempts AS (
          SELECT
            e.match_id,
            COUNT(DISTINCT CASE WHEN e.is_deleted = 0 AND
              (e.type = 'score' OR e.type = 'fieldGoal' OR e.type = 'miss')
              THEN e.id END) AS shot_attempt_count,
            COUNT(DISTINCT CASE WHEN e.is_deleted = 0 AND
              (e.type = 'score' OR e.type = 'fieldGoal' OR e.type = 'miss') AND
              locations.is_confirmed = 1 THEN e.id END) AS located_shot_count
          FROM match_events e
          INNER JOIN candidates c ON c.match_id = e.match_id
          LEFT JOIN shot_locations locations ON locations.event_id = e.id
          GROUP BY e.match_id
        )
        SELECT
          c.match_id AS match_id,
          c.played_at AS played_at,
          c.started_at AS started_at,
          c.created_at AS created_at,
          c.ended_at AS ended_at,
          c.note AS note,
          c.lifecycle AS lifecycle,
          c.recording_mode AS recording_mode,
          c.tracking_coverage AS tracking_coverage,
          c.rule_json AS rule_json,
          c.red_name AS red_name,
          c.red_profile_id AS red_profile_id,
          c.red_profile_nickname AS red_profile_nickname,
          c.blue_name AS blue_name,
          c.blue_profile_id AS blue_profile_id,
          c.blue_profile_nickname AS blue_profile_nickname,
          COALESCE(scores.red_score, 0) AS red_score,
          COALESCE(scores.blue_score, 0) AS blue_score,
          COALESCE(attempts.shot_attempt_count, 0) AS shot_attempt_count,
          COALESCE(attempts.located_shot_count, 0) AS located_shot_count
        FROM candidates c
        LEFT JOIN scores ON scores.match_id = c.match_id
        LEFT JOIN attempts ON attempts.match_id = c.match_id
        ORDER BY c.played_at DESC, c.match_id DESC
      ''',
      variables: variables,
    );
  }

  MatchHistoryPage _mapHistoryPage(
    List<QueryRow> rows, {
    required int offset,
    required int limit,
  }) {
    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.take(limit) : rows;
    final entries = pageRows.map(_mapHistoryRow).toList(growable: false);
    return MatchHistoryPage(
      entries: entries,
      offset: offset,
      limit: limit,
      hasMore: hasMore,
    );
  }

  MatchHistoryEntry _mapHistoryRow(QueryRow row) {
    final startedAt = row.read<DateTime?>('started_at')?.toUtc();
    final createdAt = row.read<DateTime>('created_at').toUtc();
    final endedAt = row.read<DateTime?>('ended_at')?.toUtc();
    final playedAt = row.read<DateTime>('played_at').toUtc();
    final redScore = row.read<int>('red_score');
    final blueScore = row.read<int>('blue_score');
    final attempts = row.read<int>('shot_attempt_count');
    final located = row.read<int>('located_shot_count');
    final rule = _ruleTemplateFromJson(row.read<String>('rule_json'));
    final lifecycle = domain_match.MatchLifecycle.values.byName(
      row.read<String>('lifecycle'),
    );
    final duration = endedAt?.difference(startedAt ?? createdAt);
    return MatchHistoryEntry(
      id: row.read<String>('match_id'),
      playedAt: playedAt,
      redName: row.read<String?>('red_name') ?? '',
      blueName: row.read<String?>('blue_name') ?? '',
      redScore: redScore,
      blueScore: blueScore,
      winner: redScore == blueScore
          ? null
          : redScore > blueScore
          ? TeamSide.red
          : TeamSide.blue,
      ruleName: rule.name,
      duration: duration,
      shotAttemptCount: attempts,
      locatedShotCount: located,
      shotLocationCompleteness: attempts == 0 ? 0 : located / attempts,
      lifecycle: lifecycle,
      importedIncomplete: _isImportedIncompleteNote(row.read<String?>('note')),
      recordingMode: RecordingMode.values.byName(
        row.read<String>('recording_mode'),
      ),
      trackingCoverage: TrackingCoverage.values.byName(
        row.read<String>('tracking_coverage'),
      ),
      ruleId: rule.id,
      redPlayerProfileId: row.read<String?>('red_profile_id'),
      bluePlayerProfileId: row.read<String?>('blue_profile_id'),
      redPlayerNickname: row.read<String?>('red_profile_nickname'),
      bluePlayerNickname: row.read<String?>('blue_profile_nickname'),
    );
  }

  static MatchEvent mapEventRow(MatchEventRow row) {
    final type = MatchEventType.values.byName(row.type);
    final side = row.side == null ? null : TeamSide.values.byName(row.side!);

    if (type == MatchEventType.score && (side == null || row.points <= 0)) {
      throw StateError(
        'Invalid persisted score event ${row.id}: score events require side '
        'and positive points.',
      );
    }

    return MatchEvent(
      id: row.id,
      matchId: row.matchId,
      type: type,
      side: side,
      points: row.points,
      occurredAt: row.occurredAt.toUtc(),
      note: row.note,
      customLabel: row.customLabel,
      outcome: row.outcome == null
          ? null
          : ShotOutcome.values.byName(row.outcome!),
      matchClockPositionSeconds: row.matchClockPositionSeconds,
      isDeleted: row.isDeleted,
    );
  }

  static domain_match.Match mapMatchRow(
    Matche row, {
    List<dynamic>? participantRows,
  }) {
    final participants =
        participantRows
            ?.map(
              (participant) => domain_match.MatchParticipant(
                id: participant.id,
                matchId: participant.matchId,
                side: TeamSide.values.byName(participant.side),
                nameSnapshot: participant.nameSnapshot,
                playerProfileId: participant.playerProfileId,
              ),
            )
            .toList(growable: false) ??
        const <domain_match.MatchParticipant>[];
    return domain_match.Match(
      id: row.id,
      createdAt: row.createdAt.toUtc(),
      startedAt: row.startedAt?.toUtc(),
      endedAt: row.endedAt?.toUtc(),
      participants: participants.length == 2 ? participants : const [],
      lifecycle: domain_match.MatchLifecycle.values.byName(row.lifecycle),
      ruleTemplateSnapshot: _ruleTemplateFromJson(row.ruleTemplateJson),
      recordingMode: domain_match.RecordingMode.values.byName(
        row.recordingMode,
      ),
      trackingCoverage: domain_match.TrackingCoverage.values.byName(
        row.trackingCoverage,
      ),
      timerEnabled: row.timerEnabled,
      note: row.note,
    );
  }

  static MatchEventsCompanion _eventCompanion(MatchEvent event) {
    return MatchEventsCompanion.insert(
      id: event.id,
      matchId: event.matchId,
      type: event.type.name,
      side: Value(event.side?.name),
      points: Value(event.points),
      outcome: Value(event.outcome?.name),
      matchClockPositionSeconds: Value(event.matchClockPositionSeconds),
      occurredAt: event.occurredAt,
      note: Value(event.note),
      customLabel: Value(event.customLabel),
      isDeleted: Value(event.isDeleted),
    );
  }

  static ShotLocationsCompanion _shotLocationCompanion(
    domain.ShotLocation location,
  ) {
    return ShotLocationsCompanion.insert(
      id: location.id,
      matchId: location.matchId,
      eventId: location.eventId,
      x: location.point.x,
      y: location.point.y,
      isConfirmed: Value(location.isConfirmed),
    );
  }

  static domain.ShotLocation _mapShotLocationRow(ShotLocation row) {
    return domain.ShotLocation(
      id: row.id,
      matchId: row.matchId,
      eventId: row.eventId,
      point: CourtPoint(x: row.x, y: row.y),
      isConfirmed: row.isConfirmed,
    );
  }

  /// Builds a committed projection from rows that were read by the caller.
  ///
  /// Command handlers use this inside their transaction so a receipt can
  /// retain the exact projection produced by that commit without opening a
  /// nested transaction or observing a later state.
  static MatchDetail buildDetail(
    Matche matchRow,
    List<MatchEventRow> eventRows,
    List<ShotLocation> locationRows, {
    List<dynamic> participantRows = const [],
    List<PossessionSegment> possessionRows = const [],
    domain_session.ActiveSession? activeSession,
    ClockProjection? clock,
  }) {
    final events = eventRows.map(mapEventRow).toList(growable: false);
    final activeEventIds = events
        .where((event) => !event.isDeleted)
        .map((event) => event.id)
        .toSet();
    // Unconfirmed rows remain durable so a location can be reconfirmed with
    // the same identity, but they are deliberately absent from every public
    // projection. Deleted events likewise hide their historical locations.
    final locations = locationRows
        .where(
          (location) =>
              location.isConfirmed && activeEventIds.contains(location.eventId),
        )
        .map(_mapShotLocationRow)
        .toList(growable: false);
    final eventOrder = <String, int>{
      for (var index = 0; index < events.length; index++)
        events[index].id: index,
    };
    final orderedPossessionRows = [...possessionRows]
      ..sort(
        (left, right) => (eventOrder[left.startedAtEventId] ?? events.length)
            .compareTo(eventOrder[right.startedAtEventId] ?? events.length),
      );
    final possessionSegments = orderedPossessionRows
        .map(
          (row) => domain_possession.PossessionSegment(
            id: row.id,
            matchId: row.matchId,
            side: TeamSide.values.byName(row.side),
            startedAtEventId: row.startedAtEventId,
            endedAtEventId: row.endedAtEventId,
            reason: row.reason,
            source: PossessionSource.values.byName(row.source),
          ),
        )
        .toList(growable: false);
    final activeEvents = events.where((event) => !event.isDeleted).toList();
    final score = ScoringReducer().reduce(activeEvents);
    final shotEventIds = activeEvents
        .where(
          (event) =>
              event.type == MatchEventType.score ||
              event.type == MatchEventType.fieldGoal ||
              event.type == MatchEventType.miss,
        )
        .map((event) => event.id)
        .toSet();
    final locatedEventIds = locations
        .where(
          (location) =>
              location.isConfirmed && shotEventIds.contains(location.eventId),
        )
        .map((location) => location.eventId)
        .toSet();

    final match = mapMatchRow(matchRow, participantRows: participantRows);
    final redFouls = _countFouls(activeEvents, TeamSide.red);
    final blueFouls = _countFouls(activeEvents, TeamSide.blue);
    final decision = _decisionFromEvents(
      events,
      redScore: score.redScore,
      blueScore: score.blueScore,
      clock: clock,
    );
    final warnings = _warningsFor(
      match.ruleTemplateSnapshot,
      redFouls: redFouls,
      blueFouls: blueFouls,
    );

    return MatchDetail(
      match: match,
      events: List.unmodifiable(events),
      shotLocations: List.unmodifiable(locations),
      possessionSegments: List.unmodifiable(possessionSegments),
      redScore: score.redScore,
      blueScore: score.blueScore,
      redFouls: redFouls,
      blueFouls: blueFouls,
      shotAttemptCount: shotEventIds.length,
      locatedShotCount: locatedEventIds.length,
      activeSession: activeSession,
      clock: clock,
      decision: decision,
      warnings: warnings,
    );
  }

  static MatchDecision? _decisionFromEvents(
    List<MatchEvent> events, {
    required int redScore,
    required int blueScore,
    ClockProjection? clock,
  }) {
    MatchEvent? latestSemantic;
    for (final event in events.reversed) {
      if (!event.isDeleted &&
          event.type == EventKind.pause &&
          event.customLabel != null) {
        latestSemantic = event;
        break;
      }
    }
    final label = latestSemantic?.customLabel;
    MatchDecisionReason? reason;
    if (label != null && label.startsWith('decision:')) {
      final name = label.substring('decision:'.length);
      reason = MatchDecisionReason.values
          .where((value) => value.name == name)
          .firstOrNull;
    }
    if (reason == null && clock?.phase == ClockPhase.regulationExpired) {
      reason = MatchDecisionReason.regulationExpired;
    }
    if (reason == null) return null;
    final message = switch (reason) {
      MatchDecisionReason.targetReached => '已达到目标分数，请确认结束或继续',
      MatchDecisionReason.winByTwoRequired => '已达到目标分数，但还需领先两分，请继续',
      MatchDecisionReason.regulationExpired => '常规时间结束，请确认结束或进入加时',
    };
    return MatchDecision(
      kind: MatchDecisionKind.finishOrContinue,
      reason: reason,
      redScore: redScore,
      blueScore: blueScore,
      canFinish: reason != MatchDecisionReason.winByTwoRequired,
      message: message,
      messageKey: reason.name,
    );
  }

  static List<MatchRuleWarning> _warningsFor(
    RuleTemplate template, {
    required int redFouls,
    required int blueFouls,
  }) {
    final limit = template.foulLimit;
    if (limit == null || limit <= 0) {
      return const <MatchRuleWarning>[];
    }
    final warnings = <MatchRuleWarning>[];
    if (redFouls >= limit) {
      warnings.add(
        MatchRuleWarning(
          kind: MatchWarningKind.foulLimit,
          side: TeamSide.red,
          count: redFouls,
          limit: limit,
          message: 'Red foul limit reached.',
        ),
      );
    }
    if (blueFouls >= limit) {
      warnings.add(
        MatchRuleWarning(
          kind: MatchWarningKind.foulLimit,
          side: TeamSide.blue,
          count: blueFouls,
          limit: limit,
          message: 'Blue foul limit reached.',
        ),
      );
    }
    return List.unmodifiable(warnings);
  }

  static ClockProjection _projectClock(MatchClock row) {
    final state = ClockState(
      id: row.id,
      matchId: row.matchId,
      mode: ClockMode.values.byName(row.mode),
      phase: ClockPhase.values.byName(row.phase),
      accumulatedSeconds: row.accumulatedSeconds,
      runningSinceUtc: row.runningSinceUtc?.toUtc(),
      regulationSeconds: row.regulationSeconds,
    );
    return const ClockEngine().project(state: state, now: DateTime.now());
  }

  static int _countFouls(List<MatchEvent> events, TeamSide side) {
    return events
        .where(
          (event) => event.type == MatchEventType.foul && event.side == side,
        )
        .length;
  }

  static Map<String, Object?> _ruleTemplateToJson(RuleTemplate template) {
    return {
      'id': template.id,
      'name': template.name,
      'scoreButtons': template.scoreButtons,
      'targetScore': template.targetScore,
      'timeLimitSeconds': template.timeLimitSeconds,
      'winByTwo': template.winByTwo,
      'foulLimit': template.foulLimit,
      'possessionHintEnabled': template.possessionHintEnabled,
      'possessionPolicy': template.possessionPolicy.name,
      'customEventTypes': template.customEventTypes,
    };
  }

  static RuleTemplate _ruleTemplateFromJson(String encoded) {
    final json = (jsonDecode(encoded) as Map).cast<String, Object?>();
    return RuleTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      scoreButtons: (json['scoreButtons'] as List<Object?>)
          .cast<num>()
          .map((value) => value.toInt())
          .toList(growable: false),
      targetScore: (json['targetScore'] as num?)?.toInt(),
      timeLimitSeconds: (json['timeLimitSeconds'] as num?)?.toInt(),
      winByTwo: json['winByTwo'] as bool? ?? false,
      foulLimit: (json['foulLimit'] as num?)?.toInt(),
      possessionHintEnabled: json['possessionHintEnabled'] as bool? ?? false,
      possessionPolicy: json['possessionPolicy'] == null
          ? PossessionPolicy.manual
          : PossessionPolicy.values.byName(json['possessionPolicy'] as String),
      customEventTypes: (json['customEventTypes'] as List<Object?>? ?? const [])
          .cast<String>(),
    );
  }

  static bool _isImportedIncompleteNote(String? note) {
    final value = note?.trim();
    return value == importedIncompleteNoteMarker ||
        (value?.endsWith('[$importedIncompleteNoteMarker]') ?? false);
  }
}

class _HistoryQuerySpec {
  const _HistoryQuerySpec({required this.sql, required this.variables})
    : empty = false;

  const _HistoryQuerySpec.empty()
    : sql = '',
      variables = const [],
      empty = true;

  final String sql;
  final List<Variable<Object>> variables;
  final bool empty;
}
