import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/player_analytics_snapshot_repository.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

/// A typed failure raised after a validated backup could not be merged.
///
/// Validation failures are deliberately rethrown as their original
/// [BackupException] subtype. This exception is reserved for failures while
/// planning or applying a merge transaction, so callers can distinguish bad
/// input from an atomic database failure.
class BackupMergeException implements Exception {
  const BackupMergeException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'BackupMergeException: $message'
      : 'BackupMergeException: $message ($cause)';
}

/// The auditable outcome of a deterministic merge.
class BackupMergeResult {
  BackupMergeResult({
    required this.sourceChecksum,
    required Map<String, Map<String, String>> idMap,
    required Map<String, List<String>> skippedIds,
    required Map<String, List<String>> insertedIds,
    required this.importedActiveSession,
    required this.rebuiltAnalyticsSnapshotCount,
  }) : idMap = _freezeNestedMap(idMap),
       skippedIds = _freezeListMap(skippedIds),
       insertedIds = _freezeListMap(insertedIds);

  final String sourceChecksum;
  final Map<String, Map<String, String>> idMap;
  final Map<String, List<String>> skippedIds;
  final Map<String, List<String>> insertedIds;
  final bool importedActiveSession;
  final int rebuiltAnalyticsSnapshotCount;

  int get insertedRowCount =>
      insertedIds.values.fold<int>(0, (total, ids) => total + ids.length);

  bool get changed => insertedRowCount != 0;

  BackupMergeResult withRebuiltAnalyticsSnapshotCount(int count) =>
      BackupMergeResult(
        sourceChecksum: sourceChecksum,
        idMap: idMap,
        skippedIds: skippedIds,
        insertedIds: insertedIds,
        importedActiveSession: importedActiveSession,
        rebuiltAnalyticsSnapshotCount: count,
      );

  /// Only mappings that changed a primary key, grouped by persisted table.
  Map<String, Map<String, String>> get remappedIds => {
    for (final entry in idMap.entries)
      entry.key: {
        for (final mapping in entry.value.entries)
          if (mapping.key != mapping.value) mapping.key: mapping.value,
      },
  };

  static Map<String, Map<String, String>> _freezeNestedMap(
    Map<String, Map<String, String>> source,
  ) {
    return Map<String, Map<String, String>>.unmodifiable({
      for (final entry in source.entries)
        entry.key: Map<String, String>.unmodifiable({
          for (final mapping in entry.value.entries)
            mapping.key.toString(): mapping.value.toString(),
        }),
    });
  }

  static Map<String, List<String>> _freezeListMap(
    Map<String, List<String>> source,
  ) {
    return Map<String, List<String>>.unmodifiable({
      for (final entry in source.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    });
  }
}

/// Merges a validated full-library backup into an existing database.
///
/// The optional positional and named codec forms are both accepted to keep
/// this service easy to compose in providers and in tests. A default codec is
/// only used for decoding; merge does not export through it.
class BackupMergeService {
  BackupMergeService(this.database, [JsonBackupCodec? positionalCodec])
    : codec =
          positionalCodec ?? JsonBackupCodec(database, appVersion: 'unknown');

  BackupMergeService.withCodec(this.database, {required this.codec});

  final AppDatabase database;
  final JsonBackupCodec codec;

  Future<BackupMergeResult> merge(String source) async {
    // This is the only decode/validation entry point. It completes before the
    // transaction starts, ensuring malformed input can never partially mutate
    // local data.
    final document = codec.decodeAndValidate(source);
    try {
      late final BackupMergeResult result;
      await database.transaction(() async {
        final local = await _readLocalRows();
        final plan = _buildPlan(document, local);
        await _applyPlan(plan);
        final rebuiltCount = await PlayerAnalyticsSnapshotRepository(
          database,
        ).ensureSnapshotsForMatches(plan.snapshotMatchIds);
        result = plan.result.withRebuiltAnalyticsSnapshotCount(rebuiltCount);
      });
      return result;
    } on BackupMergeException {
      rethrow;
    } on Object catch (error) {
      throw BackupMergeException(
        'Atomic backup merge failed; local data was rolled back.',
        cause: error,
      );
    }
  }

  Future<_LocalRows> _readLocalRows() async {
    return _LocalRows(
      matches: await database.select(database.matches).get(),
      participants: await database.select(database.matchParticipants).get(),
      clocks: await database.select(database.matchClocks).get(),
      events: await database.select(database.matchEvents).get(),
      locations: await database.select(database.shotLocations).get(),
      players: await database.select(database.players).get(),
      templates: await database.select(database.ruleTemplates).get(),
      possessions: await database.select(database.possessionSegments).get(),
      audits: await database.select(database.auditLogs).get(),
    );
  }

  _MergePlan _buildPlan(JsonBackupDocument document, _LocalRows local) {
    final sourceChecksum = document.manifest.checksum;
    final playerRows = _mapRows(
      table: 'players',
      sourceRows: document.data['players']!,
      localRows: _toJsonRows(local.players),
      checksum: sourceChecksum,
    );
    final templateRows = _mapRows(
      table: 'ruleTemplates',
      sourceRows: document.data['ruleTemplates']!,
      localRows: _toJsonRows(local.templates),
      checksum: sourceChecksum,
    );
    final forceMatchRemapIds = _matchIdsRequiringRemap(
      document,
      local,
      playerRows.idMap,
    );
    final matchRows = _mapRows(
      table: 'matches',
      sourceRows: document.data['matches']!,
      localRows: _toJsonRows(local.matches),
      checksum: sourceChecksum,
      forceRemapIds: forceMatchRemapIds,
      transform: (row) {
        final result = Map<String, dynamic>.from(row);
        final rule = _decodeRuleSnapshot(result['ruleTemplateJson']);
        final sourceRuleId = rule?['id'];
        final mappedRuleId = sourceRuleId is String
            ? templateRows.idMap[sourceRuleId]
            : null;
        if (mappedRuleId != null && mappedRuleId != sourceRuleId) {
          final mappedRule = Map<String, dynamic>.from(rule!);
          mappedRule['id'] = mappedRuleId;
          result['ruleTemplateJson'] = jsonEncode(mappedRule);
        }
        if (result['lifecycle'] == 'active' || result['lifecycle'] == 'draft') {
          result['lifecycle'] = 'abandoned';
          result['note'] = _appendImportedIncomplete(result['note']);
        }
        return result;
      },
    );
    final importedUnfinishedMatchIds = {
      for (final match in document.matches)
        if (match.lifecycle == 'active' || match.lifecycle == 'draft') match.id,
    };
    final participantRows = _mapRows(
      table: 'matchParticipants',
      sourceRows: document.data['matchParticipants']!,
      localRows: _toJsonRows(local.participants),
      checksum: sourceChecksum,
      transform: (row) {
        final result = Map<String, dynamic>.from(row);
        result['matchId'] =
            matchRows.idMap[result['matchId']] ?? result['matchId'];
        final profileId = result['playerProfileId'];
        if (profileId is String) {
          result['playerProfileId'] = playerRows.idMap[profileId] ?? profileId;
        }
        return result;
      },
    );
    final clockRows = _mapRows(
      table: 'matchClocks',
      sourceRows: document.data['matchClocks']!,
      localRows: _toJsonRows(local.clocks),
      checksum: sourceChecksum,
      transform: (row) {
        final result = Map<String, dynamic>.from(row);
        final sourceMatchId = result['matchId'];
        result['matchId'] =
            matchRows.idMap[result['matchId']] ?? result['matchId'];
        if (sourceMatchId is String &&
            importedUnfinishedMatchIds.contains(sourceMatchId)) {
          _pauseImportedClock(result, document.manifest.exportedAt);
        }
        return result;
      },
    );
    final eventRows = _mapRows(
      table: 'matchEvents',
      sourceRows: document.data['matchEvents']!,
      localRows: _toJsonRows(local.events),
      checksum: sourceChecksum,
      forceRemapIds: _eventIdsRequiringRemap(document, local, matchRows.idMap),
      transform: (row) {
        final result = Map<String, dynamic>.from(row);
        result['matchId'] =
            matchRows.idMap[result['matchId']] ?? result['matchId'];
        return result;
      },
    );
    final locationRows = _mapRows(
      table: 'shotLocations',
      sourceRows: document.data['shotLocations']!,
      localRows: _toJsonRows(local.locations),
      checksum: sourceChecksum,
      transform: (row) {
        final result = Map<String, dynamic>.from(row);
        result['matchId'] =
            matchRows.idMap[result['matchId']] ?? result['matchId'];
        result['eventId'] =
            eventRows.idMap[result['eventId']] ?? result['eventId'];
        return result;
      },
    );
    final possessionRows = _mapRows(
      table: 'possessionSegments',
      sourceRows: document.data['possessionSegments']!,
      localRows: _toJsonRows(local.possessions),
      checksum: sourceChecksum,
      transform: (row) {
        final result = Map<String, dynamic>.from(row);
        result['matchId'] =
            matchRows.idMap[result['matchId']] ?? result['matchId'];
        result['startedAtEventId'] =
            eventRows.idMap[result['startedAtEventId']] ??
            result['startedAtEventId'];
        final ended = result['endedAtEventId'];
        if (ended is String) {
          result['endedAtEventId'] = eventRows.idMap[ended] ?? ended;
        }
        return result;
      },
    );
    final auditRows = _mapRows(
      table: 'auditLogs',
      sourceRows: document.data['auditLogs']!,
      localRows: _toJsonRows(local.audits),
      checksum: sourceChecksum,
      transform: (row) {
        final result = Map<String, dynamic>.from(row);
        result['matchId'] =
            matchRows.idMap[result['matchId']] ?? result['matchId'];
        final targetId = result['targetId'];
        if (targetId is String) {
          result['targetId'] = _mapAuditTarget(
            targetId,
            eventRows,
            locationRows,
            possessionRows,
            participantRows,
            clockRows,
            matchRows,
          );
        }
        result['beforeJson'] = _remapAuditJson(
          result['beforeJson'],
          _AuditMappings(
            matches: matchRows.idMap,
            events: eventRows.idMap,
            locations: locationRows.idMap,
            participants: participantRows.idMap,
            clocks: clockRows.idMap,
            possessions: possessionRows.idMap,
            players: playerRows.idMap,
            templates: templateRows.idMap,
          ),
        );
        result['afterJson'] = _remapAuditJson(
          result['afterJson'],
          _AuditMappings(
            matches: matchRows.idMap,
            events: eventRows.idMap,
            locations: locationRows.idMap,
            participants: participantRows.idMap,
            clocks: clockRows.idMap,
            possessions: possessionRows.idMap,
            players: playerRows.idMap,
            templates: templateRows.idMap,
          ),
        );
        return result;
      },
    );

    final result = BackupMergeResult(
      sourceChecksum: sourceChecksum,
      idMap: {
        'matches': matchRows.idMap,
        'matchParticipants': participantRows.idMap,
        'matchClocks': clockRows.idMap,
        'matchEvents': eventRows.idMap,
        'shotLocations': locationRows.idMap,
        'players': playerRows.idMap,
        'ruleTemplates': templateRows.idMap,
        'possessionSegments': possessionRows.idMap,
        'auditLogs': auditRows.idMap,
        'activeSessions': <String, String>{},
        'appSettings': <String, String>{},
      },
      skippedIds: {
        'matches': matchRows.skippedIds,
        'matchParticipants': participantRows.skippedIds,
        'matchClocks': clockRows.skippedIds,
        'matchEvents': eventRows.skippedIds,
        'shotLocations': locationRows.skippedIds,
        'players': playerRows.skippedIds,
        'ruleTemplates': templateRows.skippedIds,
        'possessionSegments': possessionRows.skippedIds,
        'auditLogs': auditRows.skippedIds,
        'activeSessions': [for (final _ in document.activeSessions) 'active'],
        'appSettings': [
          for (final row in document.data['appSettings']!) row['key'] as String,
        ],
      },
      insertedIds: {
        'matches': matchRows.insertedIds,
        'matchParticipants': participantRows.insertedIds,
        'matchClocks': clockRows.insertedIds,
        'matchEvents': eventRows.insertedIds,
        'shotLocations': locationRows.insertedIds,
        'players': playerRows.insertedIds,
        'ruleTemplates': templateRows.insertedIds,
        'possessionSegments': possessionRows.insertedIds,
        'auditLogs': auditRows.insertedIds,
        'activeSessions': const <String>[],
        'appSettings': const <String>[],
      },
      importedActiveSession: document.activeSessions.isNotEmpty,
      rebuiltAnalyticsSnapshotCount: 0,
    );
    final snapshotMatchIds = <String>{
      for (final group in [
        matchRows.rows,
        participantRows.rows,
        eventRows.rows,
        locationRows.rows,
      ])
        for (final row in group)
          if (row['matchId'] case final String matchId) matchId,
      for (final row in matchRows.rows)
        if (row['id'] case final String matchId) matchId,
    };
    return _MergePlan(
      matches: matchRows.rows,
      participants: participantRows.rows,
      clocks: clockRows.rows,
      events: eventRows.rows,
      locations: locationRows.rows,
      players: playerRows.rows,
      templates: templateRows.rows,
      possessions: possessionRows.rows,
      audits: auditRows.rows,
      snapshotMatchIds: snapshotMatchIds,
      result: result,
    );
  }

  Future<void> _applyPlan(_MergePlan plan) async {
    for (final row in plan.players) {
      await database.into(database.players).insert(PlayerRow.fromJson(row));
    }
    for (final row in plan.templates) {
      await database
          .into(database.ruleTemplates)
          .insert(RuleTemplateRow.fromJson(row));
    }
    for (final row in plan.matches) {
      await database.into(database.matches).insert(Matche.fromJson(row));
    }
    for (final row in plan.participants) {
      await database
          .into(database.matchParticipants)
          .insert(MatchParticipant.fromJson(row));
    }
    for (final row in plan.clocks) {
      await database
          .into(database.matchClocks)
          .insert(MatchClock.fromJson(row));
    }
    for (final row in plan.events) {
      await database
          .into(database.matchEvents)
          .insert(MatchEventRow.fromJson(row));
    }
    for (final row in plan.locations) {
      await database
          .into(database.shotLocations)
          .insert(ShotLocation.fromJson(row));
    }
    for (final row in plan.possessions) {
      await database
          .into(database.possessionSegments)
          .insert(PossessionSegment.fromJson(row));
    }
    for (final row in plan.audits) {
      await database.into(database.auditLogs).insert(AuditLog.fromJson(row));
    }
    // appSettings and activeSessions are intentionally not inserted. Imported
    // settings must never overwrite local preferences, and an imported active
    // session must never claim the local active slot.
  }

  Set<String> _matchIdsRequiringRemap(
    JsonBackupDocument document,
    _LocalRows local,
    Map<String, String> playerIdMap,
  ) {
    final localParticipants = _toJsonRows(local.participants);
    final localById = <String, Map<String, dynamic>>{
      for (final row in localParticipants) row['id'] as String: row,
    };
    final localByMatchSide = <String, Map<String, dynamic>>{
      for (final row in localParticipants)
        '${row['matchId']}:${row['side']}': row,
    };
    final result = <String>{};
    for (final source in document.data['matchParticipants']!) {
      final transformed = Map<String, dynamic>.from(source);
      final profileId = transformed['playerProfileId'];
      if (profileId is String) {
        transformed['playerProfileId'] = playerIdMap[profileId] ?? profileId;
      }
      final matchId = transformed['matchId'] as String;
      final localWithId = localById[transformed['id']];
      if (localWithId != null &&
          localWithId['matchId'] == matchId &&
          !_sameRow(localWithId, transformed)) {
        result.add(matchId);
        continue;
      }
      final localWithSide = localByMatchSide['$matchId:${transformed['side']}'];
      if (localWithSide != null && localWithSide['id'] != transformed['id']) {
        result.add(matchId);
      }
    }
    final localClocksByMatch = <String, Map<String, dynamic>>{
      for (final row in _toJsonRows(local.clocks))
        row['matchId'] as String: row,
    };
    for (final source in document.data['matchClocks']!) {
      final matchId = source['matchId'];
      if (matchId is! String) continue;
      final localClock = localClocksByMatch[matchId];
      if (localClock != null && !_sameRow(localClock, source)) {
        // match_clocks.match_id is unique. A clock conflict is therefore a
        // conflict of the complete match graph, not a reason to allocate a
        // second clock under the same match.
        result.add(matchId);
      }
    }
    return result;
  }

  Set<String> _eventIdsRequiringRemap(
    JsonBackupDocument document,
    _LocalRows local,
    Map<String, String> matchIdMap,
  ) {
    final localLocationsByEvent = <String, Map<String, dynamic>>{
      for (final row in _toJsonRows(local.locations))
        row['eventId'] as String: row,
    };
    final sourceEventsById = <String, Map<String, dynamic>>{
      for (final row in document.data['matchEvents']!) row['id'] as String: row,
    };
    final result = <String>{};
    for (final source in document.data['shotLocations']!) {
      final eventId = source['eventId'];
      if (eventId is! String) continue;
      final localLocation = localLocationsByEvent[eventId];
      if (localLocation == null) continue;
      final event = sourceEventsById[eventId];
      final transformed = Map<String, dynamic>.from(source);
      final sourceMatchId = event?['matchId'];
      if (sourceMatchId is String) {
        transformed['matchId'] = matchIdMap[sourceMatchId] ?? sourceMatchId;
      }
      if (!_sameRow(localLocation, transformed)) {
        // shot_locations.event_id is unique. A differing location cannot be
        // inserted as a second row for the same event, so remap the event and
        // let all event/location/possession/audit references follow it.
        result.add(eventId);
      }
    }
    return result;
  }

  _MappedRows _mapRows({
    required String table,
    required List<Map<String, dynamic>> sourceRows,
    required List<Map<String, dynamic>> localRows,
    required String checksum,
    Set<String> forceRemapIds = const <String>{},
    Map<String, dynamic> Function(Map<String, dynamic> row)? transform,
  }) {
    final localById = <String, Map<String, dynamic>>{
      for (final row in localRows) row['id'] as String: row,
    };
    final reservedIds = <String>{
      ...localById.keys,
      for (final row in sourceRows) row['id'] as String,
    };
    final usedIds = <String>{...reservedIds};
    final mapped = <String, String>{};
    final skipped = <String>[];
    final inserted = <String>[];
    final rows = <Map<String, dynamic>>[];
    for (final source in sourceRows) {
      final oldId = source['id'] as String;
      final transformed = Map<String, dynamic>.from(
        transform?.call(Map<String, dynamic>.from(source)) ?? source,
      );
      final localWithOldId = localById[oldId];
      final forceRemap = forceRemapIds.contains(oldId);
      if (!forceRemap &&
          localWithOldId != null &&
          _sameRow(localWithOldId, transformed)) {
        mapped[oldId] = oldId;
        skipped.add(oldId);
        continue;
      }

      var targetId = oldId;
      if (localWithOldId != null || forceRemap) {
        targetId = _allocateRemappedId(
          table: table,
          oldId: oldId,
          checksum: checksum,
          transformed: transformed,
          localById: localById,
          usedIds: usedIds,
        );
      } else {
        // A previous merge of the same checksum may already have placed this
        // source row at its deterministic remapped ID. Recognize that exact
        // row before considering the original ID available.
        final candidate = _findExistingRemap(
          table: table,
          oldId: oldId,
          checksum: checksum,
          transformed: transformed,
          localById: localById,
        );
        if (candidate != null) {
          targetId = candidate;
          mapped[oldId] = targetId;
          skipped.add(oldId);
          continue;
        }
      }
      transformed['id'] = targetId;
      mapped[oldId] = targetId;
      final existingAtTarget = localById[targetId];
      if (existingAtTarget != null && _sameRow(existingAtTarget, transformed)) {
        skipped.add(oldId);
        continue;
      }
      rows.add(transformed);
      inserted.add(targetId);
      usedIds.add(targetId);
      localById[targetId] = transformed;
    }
    return _MappedRows(
      rows: rows,
      idMap: mapped,
      skippedIds: skipped,
      insertedIds: inserted,
    );
  }

  String _allocateRemappedId({
    required String table,
    required String oldId,
    required String checksum,
    required Map<String, dynamic> transformed,
    required Map<String, Map<String, dynamic>> localById,
    required Set<String> usedIds,
  }) {
    final base = _baseRemappedId(table, oldId, checksum);
    var candidate = base;
    var sequence = 1;
    while (true) {
      final existing = localById[candidate];
      if (existing != null &&
          _sameRow(existing, {...transformed, 'id': candidate})) {
        return candidate;
      }
      if (!usedIds.contains(candidate) && existing == null) {
        return candidate;
      }
      sequence++;
      candidate = '$base~$sequence';
    }
  }

  String? _findExistingRemap({
    required String table,
    required String oldId,
    required String checksum,
    required Map<String, dynamic> transformed,
    required Map<String, Map<String, dynamic>> localById,
  }) {
    final base = _baseRemappedId(table, oldId, checksum);
    for (var sequence = 1; sequence < 100000; sequence++) {
      final candidate = sequence == 1 ? base : '$base~$sequence';
      final existing = localById[candidate];
      if (existing == null) {
        if (sequence > 1) return null;
        continue;
      }
      if (_sameRow(existing, {...transformed, 'id': candidate})) {
        return candidate;
      }
    }
    return null;
  }

  static String _baseRemappedId(String table, String oldId, String checksum) {
    final digest = sha256
        .convert(utf8.encode('$checksum|$table|$oldId'))
        .toString()
        .substring(0, 16);
    return '$oldId~import-$digest';
  }

  static String? _mapAuditTarget(
    String targetId,
    _MappedRows events,
    _MappedRows locations,
    _MappedRows possessions,
    _MappedRows participants,
    _MappedRows clocks,
    _MappedRows matches,
  ) {
    for (final mapping in [
      events.idMap,
      locations.idMap,
      possessions.idMap,
      participants.idMap,
      clocks.idMap,
      matches.idMap,
    ]) {
      final mapped = mapping[targetId];
      if (mapped != null) return mapped;
    }
    return targetId;
  }

  /// Remaps only fields whose names carry an entity-reference contract. Audit
  /// prose is deliberately left untouched: replacing every occurrence of an
  /// old UUID in a JSON string would corrupt notes and human-readable diffs.
  static String _remapAuditJson(Object? raw, _AuditMappings mappings) {
    if (raw is! String) return raw?.toString() ?? '';
    try {
      final decoded = jsonDecode(raw);
      return jsonEncode(mappings.remapValue(decoded));
    } on Object {
      // JsonBackupCodec already rejects malformed audit JSON. Keep this
      // defensive fallback lossless for rows produced by older callers.
      return raw;
    }
  }

  static Map<String, dynamic>? _decodeRuleSnapshot(Object? value) {
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      return null;
    }
  }

  static String _appendImportedIncomplete(Object? value) {
    final note = value is String ? value.trim() : '';
    if (note.isEmpty) return importedIncompleteNoteMarker;
    if (note == importedIncompleteNoteMarker ||
        note.endsWith('[$importedIncompleteNoteMarker]')) {
      return note;
    }
    return '$note [$importedIncompleteNoteMarker]';
  }

  static void _pauseImportedClock(
    Map<String, dynamic> row,
    DateTime exportedAt,
  ) {
    final rawRunningSince = row['runningSinceUtc'];
    if (rawRunningSince is! String) return;
    final runningSince = DateTime.tryParse(rawRunningSince)?.toUtc();
    if (runningSince == null) return;
    final elapsed = exportedAt.toUtc().difference(runningSince);
    final accumulated = row['accumulatedSeconds'];
    if (accumulated is int && !elapsed.isNegative) {
      row['accumulatedSeconds'] = accumulated + elapsed.inSeconds;
    }
    row['runningSinceUtc'] = null;
  }

  static bool _sameRow(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    return _canonicalJson(first) == _canonicalJson(second);
  }

  static List<Map<String, dynamic>> _toJsonRows(Iterable<DataClass> rows) {
    return [for (final row in rows) Map<String, dynamic>.from(row.toJson())];
  }

  static String _canonicalJson(Object? value) =>
      jsonEncode(_canonicalize(value));

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalMapValue(key, value[key]),
      };
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }

  static Object? _canonicalMapValue(String key, Object? value) {
    const jsonTextColumns = {
      'ruleTemplateJson',
      'scoreButtonsJson',
      'customEventTypesJson',
      'beforeJson',
      'afterJson',
      'valueJson',
    };
    if (value is String && jsonTextColumns.contains(key)) {
      try {
        return _canonicalize(jsonDecode(value));
      } on Object {
        // The codec has already validated these columns. Keep malformed text
        // comparable if this helper is reused with a raw local row.
      }
    }
    return _canonicalize(value);
  }
}

class _LocalRows {
  const _LocalRows({
    required this.matches,
    required this.participants,
    required this.clocks,
    required this.events,
    required this.locations,
    required this.players,
    required this.templates,
    required this.possessions,
    required this.audits,
  });

  final List<Matche> matches;
  final List<MatchParticipant> participants;
  final List<MatchClock> clocks;
  final List<MatchEventRow> events;
  final List<ShotLocation> locations;
  final List<PlayerRow> players;
  final List<RuleTemplateRow> templates;
  final List<PossessionSegment> possessions;
  final List<AuditLog> audits;
}

class _MappedRows {
  const _MappedRows({
    required this.rows,
    required this.idMap,
    required this.skippedIds,
    required this.insertedIds,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, String> idMap;
  final List<String> skippedIds;
  final List<String> insertedIds;
}

class _AuditMappings {
  const _AuditMappings({
    required this.matches,
    required this.events,
    required this.locations,
    required this.participants,
    required this.clocks,
    required this.possessions,
    required this.players,
    required this.templates,
  });

  final Map<String, String> matches;
  final Map<String, String> events;
  final Map<String, String> locations;
  final Map<String, String> participants;
  final Map<String, String> clocks;
  final Map<String, String> possessions;
  final Map<String, String> players;
  final Map<String, String> templates;

  Object? remapValue(Object? value) {
    if (value is Map) {
      final source = value.map((key, child) => MapEntry(key.toString(), child));
      final inferredIdMap = _inferIdMap(source);
      return <String, Object?>{
        for (final entry in source.entries)
          entry.key: _remapField(entry.key, entry.value, inferredIdMap),
      };
    }
    if (value is Iterable) {
      return value.map(remapValue).toList(growable: false);
    }
    return value;
  }

  Object? _remapField(
    String key,
    Object? value,
    Map<String, String>? inferredIdMap,
  ) {
    if (value is String) {
      final map = switch (key) {
        'matchId' => matches,
        'eventId' ||
        'scoringEventId' ||
        'startedAtEventId' ||
        'endedAtEventId' => events,
        'locationId' || 'shotLocationId' => locations,
        'participantId' || 'matchParticipantId' => participants,
        'clockId' || 'matchClockId' => clocks,
        'possessionId' || 'segmentId' => possessions,
        'playerId' || 'playerProfileId' => players,
        'ruleId' || 'ruleTemplateId' => templates,
        'id' => inferredIdMap,
        _ => null,
      };
      if (map != null) return map[value] ?? value;
    }
    return remapValue(value);
  }

  Map<String, String>? _inferIdMap(Map<String, dynamic> source) {
    if (!source.containsKey('id')) return null;
    if (source.containsKey('eventId') ||
        source.containsKey('x') && source.containsKey('y')) {
      return locations;
    }
    if (source.containsKey('startedAtEventId') ||
        source.containsKey('endedAtEventId')) {
      return possessions;
    }
    if (source.containsKey('nameSnapshot') && source.containsKey('side')) {
      return participants;
    }
    if (source.containsKey('occurredAt') && source.containsKey('type')) {
      return events;
    }
    if (source.containsKey('mode') && source.containsKey('phase')) {
      return clocks;
    }
    if (source.containsKey('lifecycle') &&
        source.containsKey('recordingMode')) {
      return matches;
    }
    if (source.containsKey('scoreButtons') && source.containsKey('name')) {
      return templates;
    }
    if (source.containsKey('nickname')) return players;
    return null;
  }
}

class _MergePlan {
  const _MergePlan({
    required this.matches,
    required this.participants,
    required this.clocks,
    required this.events,
    required this.locations,
    required this.players,
    required this.templates,
    required this.possessions,
    required this.audits,
    required this.snapshotMatchIds,
    required this.result,
  });

  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> clocks;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> locations;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> templates;
  final List<Map<String, dynamic>> possessions;
  final List<Map<String, dynamic>> audits;
  final Set<String> snapshotMatchIds;
  final BackupMergeResult result;
}
