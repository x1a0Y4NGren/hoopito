import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:hoopito/core/audit/audit_log_entry.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/player_analytics_snapshot_repository.dart';
import 'package:hoopito/core/domain/analytics/player_analytics_snapshot.dart';
import 'package:hoopito/core/domain/analytics/player_analytics_snapshot_calculator.dart';
import 'package:hoopito/core/domain/entities/match.dart' as domain_match;
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/backup_manifest.dart';

sealed class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class BackupFormatException extends BackupException {
  const BackupFormatException(super.message);
}

class BackupChecksumException extends BackupException {
  const BackupChecksumException()
    : super('Backup checksum does not match its payload.');
}

class UnsupportedBackupSchemaException extends BackupException {
  const UnsupportedBackupSchemaException({
    required this.schemaVersion,
    required this.supportedSchemaVersion,
  }) : super(
         'Backup schema $schemaVersion is newer than supported schema '
         '$supportedSchemaVersion.',
       );

  final int schemaVersion;
  final int supportedSchemaVersion;
}

class UnsupportedBackupFormatException extends BackupException {
  const UnsupportedBackupFormatException({
    required this.formatVersion,
    required this.supportedFormatVersion,
  }) : super(
         'Backup format $formatVersion is not supported; expected '
         '$supportedFormatVersion.',
       );

  final int formatVersion;
  final int supportedFormatVersion;
}

class BackupValidationException extends BackupException {
  const BackupValidationException(super.message);
}

enum BackupCapacityLimit { payloadBytes, rowsPerTable, totalRows }

/// Reports measured capacity and the supported limit for localized feedback.
class BackupCapacityException extends BackupValidationException {
  const BackupCapacityException({
    required this.limitKind,
    required this.measured,
    required this.limit,
    this.tableName,
  }) : super(
         'Backup capacity${tableName == null ? '' : ' ($tableName)'} '
         'is $measured; the supported limit is $limit.',
       );

  final BackupCapacityLimit limitKind;
  final int measured;
  final int limit;
  final String? tableName;
}

class BackupRestoreException extends BackupException {
  const BackupRestoreException(super.message);
}

class SafetyBackupWriteException extends BackupException {
  const SafetyBackupWriteException()
    : super('The internal safety backup could not be saved and verified.');
}

/// Raised when replace restore would delete a locally active match.
///
/// The invariant is enforced inside the same transaction that performs the
/// replacement so a session started while a document picker is open cannot be
/// lost.
class BackupRestoreBlockedException extends BackupException {
  const BackupRestoreBlockedException()
    : super(
        'Finish the active match before replacing local data from a backup.',
      );
}

/// A backup document after all envelope, row, domain and graph checks have
/// completed. Consumers that import a backup should use this view so the
/// complete validation pass is shared before any mutation begins.
class JsonBackupDocument {
  const JsonBackupDocument({
    required this.manifest,
    required this.data,
    required this.matches,
    required this.participants,
    required this.clocks,
    required this.activeSessions,
    required this.events,
    required this.locations,
    required this.players,
    required this.templates,
    required this.possessions,
    required this.audits,
    required this.settings,
    required this.snapshots,
  });

  final BackupManifest manifest;
  final Map<String, List<Map<String, dynamic>>> data;
  final List<Matche> matches;
  final List<MatchParticipant> participants;
  final List<MatchClock> clocks;
  final List<ActiveSession> activeSessions;
  final List<MatchEventRow> events;
  final List<ShotLocation> locations;
  final List<PlayerRow> players;
  final List<RuleTemplateRow> templates;
  final List<PossessionSegment> possessions;
  final List<AuditLog> audits;
  final List<AppSetting> settings;
  final List<PlayerAnalyticsSnapshotRow> snapshots;

  String get checksum => manifest.checksum;
}

/// Compatibility alias for callers that prefer the shorter validated name.
typedef ValidatedBackup = JsonBackupDocument;

class JsonBackupCodec {
  JsonBackupCodec(
    this.database, {
    required this.appVersion,
    DateTime Function()? now,
    this.maxPayloadBytes = 32 * 1024 * 1024,
    this.maxRowsPerTable = 100000,
    this.maxTotalRows = 200000,
  }) : now = now ?? DateTime.now;

  static const appName = 'Hoopito';
  static const currentFormatVersion = 2;

  final AppDatabase database;
  final String appVersion;
  final DateTime Function() now;
  final int maxPayloadBytes;
  final int maxRowsPerTable;
  final int maxTotalRows;

  Future<String> export() {
    // A headless WorkManager engine may run beside the foreground engine. A
    // single transaction keeps the twelve table snapshots at one SQLite
    // point in time, so graph validation can never observe a half-committed
    // domain mutation.
    return database.transaction(() async {
      _validateRecordCounts(await _exportRecordCounts());
      await PlayerAnalyticsSnapshotRepository(database).ensureSnapshots();
      _validateRecordCounts(await _exportRecordCounts());
      final tables = <String, List<Map<String, dynamic>>>{
        'matches': await _rows(database.matches),
        'matchParticipants': await _rows(database.matchParticipants),
        'matchClocks': await _rows(database.matchClocks),
        'activeSessions': await _rows(database.activeSessions),
        // Event and audit row order is the only durable chronology available
        // to pre-audit imports. Preserve SQLite insertion order in backups so
        // a round trip retains that deterministic legacy fallback.
        'matchEvents': await _rows(database.matchEvents, sortByKey: false),
        'shotLocations': await _rows(database.shotLocations),
        'players': await _rows(database.players),
        'ruleTemplates': await _rows(database.ruleTemplates),
        'possessionSegments': await _rows(database.possessionSegments),
        'auditLogs': await _rows(database.auditLogs, sortByKey: false),
        'appSettings': await _rows(
          database.appSettings,
          key: 'key',
          include: (row) => row['key'] != automaticBackupRunLeaseSettingKey,
        ),
        'playerAnalyticsSnapshots': await _rows(
          database.playerAnalyticsSnapshots,
          sortKeys: const ['matchId', 'playerId'],
        ),
      };
      final counts = <String, int>{
        for (final entry in tables.entries) entry.key: entry.value.length,
      };
      final sourceManifest = BackupManifest(
        appName: appName,
        appVersion: appVersion,
        formatVersion: currentFormatVersion,
        schemaVersion: database.schemaVersion,
        exportedAt: now().toUtc(),
        recordCounts: counts,
        checksum: '',
      );
      final checksum = _checksum(sourceManifest, tables);
      final manifest = BackupManifest(
        appName: sourceManifest.appName,
        appVersion: sourceManifest.appVersion,
        formatVersion: sourceManifest.formatVersion,
        schemaVersion: sourceManifest.schemaVersion,
        exportedAt: sourceManifest.exportedAt,
        recordCounts: sourceManifest.recordCounts,
        checksum: checksum,
      );
      final payload = jsonEncode({
        'manifest': manifest.toJson(),
        'data': tables,
      });
      _validatePayloadBytes(utf8.encode(payload).length);
      return payload;
    });
  }

  Future<void> restore(String source) async {
    final document = decodeAndValidate(source);
    final matches = document.matches;
    final participants = document.participants;
    final clocks = document.clocks
        .map(
          (clock) => _pausedRestoredClock(
            clock,
            exportedAt: document.manifest.exportedAt,
          ),
        )
        .toList(growable: false);
    final activeSessions = document.activeSessions;
    final events = document.events;
    final locations = document.locations;
    final players = document.players;
    final templates = document.templates;
    final possessions = document.possessions;
    final audits = document.audits;
    final settings = document.settings;
    final snapshots = document.snapshots;

    try {
      await database.transaction(() async {
        if ((await database.select(database.activeSessions).get()).isNotEmpty) {
          throw const BackupRestoreBlockedException();
        }
        await database.delete(database.shotLocations).go();
        await database.delete(database.playerAnalyticsSnapshots).go();
        await database.delete(database.activeSessions).go();
        await database.delete(database.possessionSegments).go();
        await database.delete(database.auditLogs).go();
        await database.delete(database.matchEvents).go();
        await database.delete(database.matchParticipants).go();
        await database.delete(database.matchClocks).go();
        await database.delete(database.matches).go();
        await database.delete(database.players).go();
        await database.delete(database.ruleTemplates).go();
        await database.delete(database.appSettings).go();

        await _insertAll(database.players, players);
        await _insertAll(database.ruleTemplates, templates);
        await _insertAll(database.appSettings, settings);
        await _insertAll(database.matches, matches);
        await _insertAll(database.matchParticipants, participants);
        await _insertAll(database.matchClocks, clocks);
        await _insertAll(database.matchEvents, events);
        await _insertAll(database.shotLocations, locations);
        await _insertAll(database.possessionSegments, possessions);
        await _insertAll(database.auditLogs, audits);
        await _insertAll(database.activeSessions, activeSessions);
        await _insertAll(database.playerAnalyticsSnapshots, snapshots);
        await PlayerAnalyticsSnapshotRepository(database).ensureSnapshots();
      });
    } on BackupRestoreBlockedException {
      rethrow;
    } on Object catch (error) {
      throw BackupRestoreException('Atomic restore failed: $error');
    }
  }

  /// Parses and fully validates [source] without touching the database.
  ///
  /// Merge/import workflows use this method to share the exact same size,
  /// version, checksum, enum, reference and domain checks as replace restore
  /// before opening their write transaction.
  JsonBackupDocument decodeAndValidate(String source) {
    _validatePayloadBytes(utf8.encode(source).length);
    late final BackupManifest manifest;
    late final Map<String, List<Map<String, dynamic>>> data;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupFormatException('Backup root must be an object.');
      }
      final manifestJson = decoded['manifest'];
      final dataJson = decoded['data'];
      if (manifestJson is! Map<String, dynamic> ||
          dataJson is! Map<String, dynamic>) {
        throw const BackupFormatException(
          'Backup must contain manifest and data objects.',
        );
      }
      manifest = BackupManifest.fromJson(manifestJson);
      data = dataJson.map((key, value) => MapEntry(key, _jsonRows(key, value)));
    } on BackupException {
      rethrow;
    } on Object catch (error) {
      throw BackupFormatException('Backup JSON is invalid: $error');
    }
    if (manifest.formatVersion < 1 ||
        manifest.formatVersion > currentFormatVersion) {
      throw UnsupportedBackupFormatException(
        formatVersion: manifest.formatVersion,
        supportedFormatVersion: currentFormatVersion,
      );
    }
    _validateResourceLimits(manifest);
    if (manifest.schemaVersion > database.schemaVersion) {
      throw UnsupportedBackupSchemaException(
        schemaVersion: manifest.schemaVersion,
        supportedSchemaVersion: database.schemaVersion,
      );
    }
    final isLegacyV1 =
        manifest.formatVersion == 1 && manifest.schemaVersion == 2;
    final isCurrent =
        manifest.formatVersion == currentFormatVersion &&
        manifest.schemaVersion == database.schemaVersion;
    if (!isLegacyV1 && !isCurrent) {
      throw BackupValidationException(
        'Backup format ${manifest.formatVersion} and schema '
        '${manifest.schemaVersion} are not a supported pair.',
      );
    }
    if (_checksum(manifest, data) != manifest.checksum) {
      throw const BackupChecksumException();
    }

    _validateTableGroups(manifest, data);
    late final List<Matche> matches;
    late final List<MatchParticipant> participants;
    late final List<MatchClock> clocks;
    late final List<ActiveSession> activeSessions;
    late final List<MatchEventRow> events;
    late final List<ShotLocation> locations;
    late final List<PlayerRow> players;
    late final List<RuleTemplateRow> templates;
    late final List<PossessionSegment> possessions;
    late final List<AuditLog> audits;
    late final List<AppSetting> settings;
    final parsedSnapshots = <PlayerAnalyticsSnapshotRow>[];
    try {
      matches = data['matches']!.map(Matche.fromJson).toList(growable: false);
      participants = data['matchParticipants']!
          .map(MatchParticipant.fromJson)
          .toList(growable: false);
      clocks = data['matchClocks']!
          .map(MatchClock.fromJson)
          .toList(growable: false);
      activeSessions = data['activeSessions']!
          .map(ActiveSession.fromJson)
          .toList(growable: false);
      events = data['matchEvents']!
          .map(MatchEventRow.fromJson)
          .toList(growable: false);
      locations = data['shotLocations']!
          .map(ShotLocation.fromJson)
          .toList(growable: false);
      players = data['players']!
          .map(PlayerRow.fromJson)
          .toList(growable: false);
      templates = data['ruleTemplates']!
          .map(RuleTemplateRow.fromJson)
          .toList(growable: false);
      possessions = data['possessionSegments']!
          .map(PossessionSegment.fromJson)
          .toList(growable: false);
      audits = data['auditLogs']!
          .map(AuditLog.fromJson)
          .toList(growable: false);
      settings = data['appSettings']!
          .map(AppSetting.fromJson)
          .toList(growable: false);
      if (!isLegacyV1) {
        for (final row in data['playerAnalyticsSnapshots']!) {
          try {
            parsedSnapshots.add(PlayerAnalyticsSnapshotRow.fromJson(row));
          } on Object {
            // Snapshot rows are derived. A malformed row is ignored after the
            // signed envelope and canonical table groups have been validated.
          }
        }
      }
    } on Object catch (error) {
      throw BackupValidationException('Backup row is invalid: $error');
    }
    _validateRows(
      matches: matches,
      participants: participants,
      clocks: clocks,
      activeSessions: activeSessions,
      events: events,
      locations: locations,
      players: players,
      templates: templates,
      possessions: possessions,
      audits: audits,
      settings: settings,
    );
    final expectedSnapshots = _calculateExpectedSnapshots(
      matches: matches,
      participants: participants,
      events: events,
      locations: locations,
    );
    final expectedByKey = {
      for (final row in expectedSnapshots) _snapshotKey(row): row,
    };
    final snapshotsByKey = <String, List<PlayerAnalyticsSnapshotRow>>{};
    for (final row in parsedSnapshots) {
      snapshotsByKey.putIfAbsent(_snapshotKey(row), () => []).add(row);
    }
    final validSnapshots = <PlayerAnalyticsSnapshotRow>[];
    if (!isLegacyV1) {
      for (final entry in snapshotsByKey.entries) {
        if (entry.value.length != 1) continue;
        final expected = expectedByKey[entry.key];
        if (expected == null) continue;
        final candidate = entry.value.single;
        if (candidate.calculatorVersion ==
                PlayerAnalyticsSnapshotCalculator.version &&
            candidate.sourceSha256 == expected.sourceSha256 &&
            _canonicalJson(candidate.toJson()) ==
                _canonicalJson(expected.toJson())) {
          validSnapshots.add(candidate);
        }
      }
    }
    final normalizedData = isLegacyV1
        ? <String, List<Map<String, dynamic>>>{
            ...data,
            'playerAnalyticsSnapshots': const [],
          }
        : data;
    return JsonBackupDocument(
      manifest: manifest,
      data: normalizedData,
      matches: matches,
      participants: participants,
      clocks: clocks,
      activeSessions: activeSessions,
      events: events,
      locations: locations,
      players: players,
      templates: templates,
      possessions: possessions,
      audits: audits,
      settings: settings,
      snapshots: validSnapshots,
    );
  }

  /// Alias kept explicit for import callers.
  JsonBackupDocument validate(String source) => decodeAndValidate(source);

  MatchClock _pausedRestoredClock(
    MatchClock clock, {
    required DateTime exportedAt,
  }) {
    final runningSince = clock.runningSinceUtc;
    if (runningSince == null) return clock;
    final elapsed = exportedAt.toUtc().difference(runningSince.toUtc());
    return clock.copyWith(
      accumulatedSeconds:
          clock.accumulatedSeconds +
          (elapsed.isNegative ? 0 : elapsed.inSeconds),
      runningSinceUtc: const Value(null),
    );
  }

  static List<Map<String, dynamic>> _jsonRows(String table, Object? value) {
    if (value is! List<dynamic>) {
      throw BackupFormatException('$table must be a JSON array.');
    }
    return value
        .map((row) {
          if (row is! Map<String, dynamic>) {
            throw BackupFormatException('$table contains a non-object row.');
          }
          return row;
        })
        .toList(growable: false);
  }

  void _validateResourceLimits(BackupManifest manifest) {
    _validateRecordCounts(manifest.recordCounts);
  }

  void _validatePayloadBytes(int measured) {
    if (measured > maxPayloadBytes) {
      throw BackupCapacityException(
        limitKind: BackupCapacityLimit.payloadBytes,
        measured: measured,
        limit: maxPayloadBytes,
      );
    }
  }

  void _validateRecordCounts(Map<String, int> counts) {
    for (final entry in counts.entries) {
      final count = entry.value;
      if (count < 0) {
        throw BackupValidationException(
          'Manifest count for ${entry.key} must not be negative.',
        );
      }
      if (count > maxRowsPerTable) {
        throw BackupCapacityException(
          limitKind: BackupCapacityLimit.rowsPerTable,
          measured: count,
          limit: maxRowsPerTable,
          tableName: entry.key,
        );
      }
    }
    final totalRows = counts.values.fold(0, (total, count) => total + count);
    if (totalRows > maxTotalRows) {
      throw BackupCapacityException(
        limitKind: BackupCapacityLimit.totalRows,
        measured: totalRows,
        limit: maxTotalRows,
      );
    }
  }

  Future<Map<String, int>> _exportRecordCounts() async {
    final tables = {
      'matches': database.matches.actualTableName,
      'matchParticipants': database.matchParticipants.actualTableName,
      'matchClocks': database.matchClocks.actualTableName,
      'activeSessions': database.activeSessions.actualTableName,
      'matchEvents': database.matchEvents.actualTableName,
      'shotLocations': database.shotLocations.actualTableName,
      'players': database.players.actualTableName,
      'ruleTemplates': database.ruleTemplates.actualTableName,
      'possessionSegments': database.possessionSegments.actualTableName,
      'auditLogs': database.auditLogs.actualTableName,
      'appSettings': database.appSettings.actualTableName,
      'playerAnalyticsSnapshots':
          database.playerAnalyticsSnapshots.actualTableName,
    };
    final counts = <String, int>{};
    for (final entry in tables.entries) {
      final excludeLease = entry.key == 'appSettings';
      final row = await database
          .customSelect(
            'SELECT COUNT(*) AS row_count FROM "${entry.value}"'
            '${excludeLease ? ' WHERE key != ?' : ''}',
            variables: [
              if (excludeLease)
                const Variable(automaticBackupRunLeaseSettingKey),
            ],
          )
          .getSingle();
      counts[entry.key] = row.read<int>('row_count');
    }
    return counts;
  }

  void _validateTableGroups(
    BackupManifest manifest,
    Map<String, List<Map<String, dynamic>>> data,
  ) {
    if ((manifest.appName != appName && manifest.appName != 'HoopTrace') ||
        manifest.appVersion.trim().isEmpty) {
      throw const BackupValidationException(
        'Backup manifest does not identify a supported Hoopito export.',
      );
    }
    const legacyExpected = {
      'matches',
      'matchParticipants',
      'matchClocks',
      'activeSessions',
      'matchEvents',
      'shotLocations',
      'players',
      'ruleTemplates',
      'possessionSegments',
      'auditLogs',
      'appSettings',
    };
    const currentExpected = {...legacyExpected, 'playerAnalyticsSnapshots'};
    final expected = manifest.formatVersion == 1
        ? legacyExpected
        : currentExpected;
    if (data.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(data.keys.toSet()).isNotEmpty) {
      throw BackupValidationException(
        'Backup must contain exactly ${manifest.formatVersion == 1 ? 'the '
                  'eleven legacy' : 'the twelve current'} persisted table groups.',
      );
    }
    if (manifest.recordCounts.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(manifest.recordCounts.keys.toSet()).isNotEmpty) {
      throw const BackupValidationException('Manifest counts are incomplete.');
    }
    for (final table in expected) {
      if (manifest.recordCounts[table] != data[table]!.length) {
        throw BackupValidationException(
          'Manifest count for $table does not match its rows.',
        );
      }
    }
  }

  void _validateRows({
    required List<Matche> matches,
    required List<MatchParticipant> participants,
    required List<MatchClock> clocks,
    required List<ActiveSession> activeSessions,
    required List<MatchEventRow> events,
    required List<ShotLocation> locations,
    required List<PlayerRow> players,
    required List<RuleTemplateRow> templates,
    required List<PossessionSegment> possessions,
    required List<AuditLog> audits,
    required List<AppSetting> settings,
  }) {
    final matchIds = _uniqueIds('matches', matches.map((row) => row.id));
    final matchesById = {for (final match in matches) match.id: match};
    _uniqueIds('matchParticipants', participants.map((row) => row.id));
    _uniqueIds('matchClocks', clocks.map((row) => row.id));
    _uniqueIds('activeSessions', activeSessions.map((row) => row.id));
    _uniqueIds('matchEvents', events.map((row) => row.id));
    _uniqueIds('shotLocations', locations.map((row) => row.id));
    _uniqueIds('players', players.map((row) => row.id));
    _uniqueIds('ruleTemplates', templates.map((row) => row.id));
    _uniqueIds('possessionSegments', possessions.map((row) => row.id));
    _uniqueIds('auditLogs', audits.map((row) => row.id));
    _uniqueIds('appSettings', settings.map((row) => row.key));

    final activeMatches = matches
        .where(
          (match) => match.lifecycle == domain_match.MatchLifecycle.active.name,
        )
        .toList(growable: false);
    if (activeMatches.length > 1 ||
        activeSessions.length > 1 ||
        activeMatches.length != activeSessions.length ||
        (activeSessions.isNotEmpty &&
            (activeSessions.single.id != 'active' ||
                !matchIds.contains(activeSessions.single.matchId) ||
                matchesById[activeSessions.single.matchId]?.lifecycle !=
                    domain_match.MatchLifecycle.active.name ||
                activeMatches.single.id != activeSessions.single.matchId))) {
      throw const BackupValidationException(
        'Backup contains an invalid active session graph.',
      );
    }

    for (final participant in participants) {
      if (!matchIds.contains(participant.matchId) ||
          !{'red', 'blue'}.contains(participant.side) ||
          participant.nameSnapshot.trim().isEmpty ||
          (participant.playerProfileId != null &&
              !players.any(
                (player) => player.id == participant.playerProfileId,
              ))) {
        throw BackupValidationException(
          'Participant ${participant.id} contains invalid references or values.',
        );
      }
    }
    final profileAssignments = <String, Set<String>>{};
    for (final participant in participants) {
      final profileId = participant.playerProfileId;
      if (profileId != null && profileId.isNotEmpty) {
        final profiles = profileAssignments.putIfAbsent(
          participant.matchId,
          () => <String>{},
        );
        if (!profiles.add(profileId)) {
          throw BackupValidationException(
            'Match ${participant.matchId} assigns player profile '
            '$profileId to both sides.',
          );
        }
      }
    }
    final participantSides = <String>{};
    for (final participant in participants) {
      if (!participantSides.add('${participant.matchId}:${participant.side}')) {
        throw BackupValidationException(
          'Match ${participant.matchId} contains duplicate participant sides.',
        );
      }
    }
    for (final matchId in matchIds) {
      final sides = participants
          .where((participant) => participant.matchId == matchId)
          .map((participant) => participant.side)
          .toSet();
      if (sides.length != 2 ||
          !sides.contains('red') ||
          !sides.contains('blue')) {
        throw BackupValidationException(
          'Match $matchId must contain exactly one red and one blue participant.',
        );
      }
    }
    for (final match in matches) {
      _validateMatch(match);
    }
    final clocksByMatch = <String, String>{};
    for (final clock in clocks) {
      final match = matchesById[clock.matchId];
      if (!matchIds.contains(clock.matchId) ||
          match == null ||
          !{'countUp', 'countdown'}.contains(clock.mode) ||
          !{
            'regulation',
            'regulationExpired',
            'overtime',
          }.contains(clock.phase) ||
          clock.accumulatedSeconds < 0 ||
          (clock.regulationSeconds != null && clock.regulationSeconds! < 0)) {
        throw BackupValidationException(
          'Clock ${clock.id} contains invalid references or values.',
        );
      }
      if (clock.runningSinceUtc != null &&
          (match.lifecycle != domain_match.MatchLifecycle.active.name ||
              clock.phase == 'regulationExpired')) {
        throw BackupValidationException(
          'Clock ${clock.id} cannot be running for its match state.',
        );
      }
      if (clocksByMatch.containsKey(clock.matchId)) {
        throw BackupValidationException(
          'Match ${clock.matchId} contains more than one clock.',
        );
      }
      clocksByMatch[clock.matchId] = clock.id;
    }
    for (final match in matches) {
      if ((match.lifecycle == domain_match.MatchLifecycle.active.name ||
              match.timerEnabled) &&
          !clocksByMatch.containsKey(match.id)) {
        throw BackupValidationException(
          'Match ${match.id} requires exactly one clock.',
        );
      }
    }

    for (final event in events) {
      if (!matchIds.contains(event.matchId)) {
        throw BackupValidationException(
          'Event ${event.id} references missing match ${event.matchId}.',
        );
      }
      if (event.type == 'score' &&
          (event.side == null ||
              event.points <= 0 ||
              (event.outcome != null && event.outcome != 'made'))) {
        throw BackupValidationException(
          'Score event ${event.id} has invalid side or points.',
        );
      }
      if ({'fieldGoal', 'freeThrow'}.contains(event.type) &&
          (event.side == null || !_hasValidShotResult(event))) {
        throw BackupValidationException(
          'Shot event ${event.id} has invalid side, outcome, or points.',
        );
      }
      if (event.type == 'miss' && (event.side == null || event.points != 0)) {
        throw BackupValidationException(
          'Miss event ${event.id} has invalid side or points.',
        );
      }
      if (!_enumNames(MatchEventType.values).contains(event.type) ||
          (event.side != null &&
              !_enumNames(TeamSide.values).contains(event.side)) ||
          event.points < 0 ||
          (event.outcome != null &&
              !_enumNames(ShotOutcome.values).contains(event.outcome)) ||
          (event.matchClockPositionSeconds != null &&
              event.matchClockPositionSeconds! < 0) ||
          (event.customLabel != null && event.customLabel!.trim().isEmpty)) {
        throw BackupValidationException(
          'Event ${event.id} contains invalid domain values.',
        );
      }
    }
    final eventsById = {for (final event in events) event.id: event};
    final locatedEventIds = <String>{};
    for (final location in locations) {
      final event = eventsById[location.eventId];
      if (!matchIds.contains(location.matchId) ||
          event == null ||
          event.matchId != location.matchId ||
          !{'fieldGoal', 'score', 'miss'}.contains(event.type) ||
          !location.x.isFinite ||
          !location.y.isFinite ||
          location.x < 0 ||
          location.x > 1 ||
          location.y < 0 ||
          location.y > 1 ||
          !locatedEventIds.add(location.eventId)) {
        throw BackupValidationException(
          'Shot location ${location.id} has invalid match/event references.',
        );
      }
    }
    for (final player in players) {
      if (player.nickname.trim().isEmpty ||
          (player.preferredSide != null &&
              !_enumNames(TeamSide.values).contains(player.preferredSide))) {
        throw BackupValidationException(
          'Player ${player.id} contains invalid domain values.',
        );
      }
    }
    for (final template in templates) {
      _validateRuleTemplate(template);
    }
    for (final possession in possessions) {
      final start = eventsById[possession.startedAtEventId];
      final end = possession.endedAtEventId == null
          ? null
          : eventsById[possession.endedAtEventId];
      if (!matchIds.contains(possession.matchId) ||
          !_enumNames(TeamSide.values).contains(possession.side) ||
          !_enumNames(PossessionSource.values).contains(possession.source) ||
          start == null ||
          start.matchId != possession.matchId ||
          (possession.endedAtEventId != null &&
              (end == null || end.matchId != possession.matchId))) {
        throw BackupValidationException(
          'Possession ${possession.id} has invalid references.',
        );
      }
    }
    for (final audit in audits) {
      if (!matchIds.contains(audit.matchId) ||
          audit.targetId.trim().isEmpty ||
          !_enumNames(AuditAction.values).contains(audit.action)) {
        throw BackupValidationException(
          'Audit ${audit.id} contains invalid domain values.',
        );
      }
      _decodeJsonObject('Audit ${audit.id} beforeJson', audit.beforeJson);
      _decodeJsonObject('Audit ${audit.id} afterJson', audit.afterJson);
    }
    for (final setting in settings) {
      _decodeJson('App setting ${setting.key}', setting.valueJson);
    }
  }

  List<PlayerAnalyticsSnapshotRow> _calculateExpectedSnapshots({
    required List<Matche> matches,
    required List<MatchParticipant> participants,
    required List<MatchEventRow> events,
    required List<ShotLocation> locations,
  }) {
    final calculator = PlayerAnalyticsSnapshotCalculator();
    final participantsByMatch = <String, List<MatchParticipant>>{};
    for (final participant in participants) {
      participantsByMatch
          .putIfAbsent(participant.matchId, () => [])
          .add(participant);
    }
    final eventsByMatch = <String, List<MatchEventRow>>{};
    for (final event in events) {
      eventsByMatch.putIfAbsent(event.matchId, () => []).add(event);
    }
    final locationByEvent = {
      for (final location in locations) location.eventId: location,
    };
    final snapshots = <PlayerAnalyticsSnapshotRow>[];
    for (final match in matches) {
      if (!{'finished', 'archived'}.contains(match.lifecycle)) continue;
      final matchParticipants = participantsByMatch[match.id] ?? const [];
      final matchEvents = eventsByMatch[match.id] ?? const [];
      for (final subject in matchParticipants) {
        final playerId = subject.playerProfileId;
        if (playerId == null) continue;
        final opponent = matchParticipants
            .where((candidate) => candidate.side != subject.side)
            .firstOrNull;
        final snapshot = calculator.calculate(
          PlayerAnalyticsSnapshotCalculationRequest(
            matchId: match.id,
            playerId: playerId,
            opponentPlayerId: opponent?.playerProfileId,
            playerSide: subject.side,
            playedAtUtc: (match.startedAt ?? match.createdAt).toUtc(),
            trackingCoverage: TrackingCoverage.values.byName(
              match.trackingCoverage,
            ),
            events: [
              for (final event in matchEvents)
                PlayerAnalyticsSnapshotEventInput(
                  id: event.id,
                  side: event.side,
                  type: EventKind.values.byName(event.type),
                  points: event.points,
                  occurredAtUtc: event.occurredAt.toUtc().toIso8601String(),
                  outcome: event.outcome == null
                      ? null
                      : ShotOutcome.values.byName(event.outcome!),
                  isDeleted: event.isDeleted,
                  location: switch (locationByEvent[event.id]) {
                    final location? => PlayerAnalyticsSnapshotLocationInput(
                      id: location.id,
                      x: location.x,
                      y: location.y,
                      isConfirmed: location.isConfirmed,
                    ),
                    null => null,
                  },
                ),
            ],
          ),
        );
        snapshots.add(_snapshotRow(snapshot));
      }
    }
    snapshots.sort((left, right) {
      final byMatch = left.matchId.compareTo(right.matchId);
      return byMatch == 0 ? left.playerId.compareTo(right.playerId) : byMatch;
    });
    return snapshots;
  }

  PlayerAnalyticsSnapshotRow _snapshotRow(PlayerAnalyticsSnapshot snapshot) =>
      PlayerAnalyticsSnapshotRow(
        matchId: snapshot.matchId,
        playerId: snapshot.playerId,
        opponentPlayerId: snapshot.opponentPlayerId,
        playedAtUtc: snapshot.playedAtUtc,
        playerScore: snapshot.playerScore,
        opponentScore: snapshot.opponentScore,
        fieldGoalMade: snapshot.fieldGoalMade,
        fieldGoalAttempts: snapshot.fieldGoalAttempts,
        freeThrowMade: snapshot.freeThrowMade,
        freeThrowAttempts: snapshot.freeThrowAttempts,
        trackingCoverage: snapshot.trackingCoverage.name,
        confirmedLocationCount: snapshot.confirmedLocationCount,
        locatableLocationCount: snapshot.locatableLocationCount,
        zoneDistributionJson: snapshot.zoneDistributionJson,
        calculatorVersion: snapshot.calculatorVersion,
        sourceSha256: snapshot.sourceSha256,
      );

  String _snapshotKey(PlayerAnalyticsSnapshotRow row) =>
      '${row.matchId}\u0000${row.playerId}';

  String _canonicalJson(Object? value) => jsonEncode(_canonicalizeJson(value));

  Object? _canonicalizeJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalizeJson(value[key]),
      };
    }
    if (value is Iterable) {
      return value.map(_canonicalizeJson).toList(growable: false);
    }
    return value;
  }

  bool _hasValidShotResult(MatchEventRow event) {
    return switch (event.outcome) {
      'made' => event.points > 0,
      'missed' => event.points == 0,
      _ => false,
    };
  }

  void _validateMatch(Matche match) {
    if (!_enumNames(
          domain_match.MatchLifecycle.values,
        ).contains(match.lifecycle) ||
        !_enumNames(
          domain_match.RecordingMode.values,
        ).contains(match.recordingMode) ||
        !_enumNames(
          domain_match.TrackingCoverage.values,
        ).contains(match.trackingCoverage) ||
        (match.startedAt != null &&
            match.startedAt!.isBefore(match.createdAt)) ||
        (match.endedAt != null &&
            match.endedAt!.isBefore(match.startedAt ?? match.createdAt))) {
      throw BackupValidationException(
        'Match ${match.id} contains invalid domain values.',
      );
    }
    final snapshot = _decodeJsonObject(
      'Match ${match.id} rule snapshot',
      match.ruleTemplateJson,
    );
    _validateRuleJson('Match ${match.id} rule snapshot', snapshot);
  }

  void _validateRuleTemplate(RuleTemplateRow template) {
    if (template.name.trim().isEmpty ||
        (template.targetScore != null && template.targetScore! <= 0) ||
        (template.timeLimitSeconds != null &&
            template.timeLimitSeconds! <= 0) ||
        (template.foulLimit != null && template.foulLimit! <= 0)) {
      throw BackupValidationException(
        'Rule template ${template.id} contains invalid values.',
      );
    }
    final scoreButtons = _decodeJson(
      'Rule template ${template.id} score buttons',
      template.scoreButtonsJson,
    );
    if (scoreButtons is! List<dynamic> ||
        scoreButtons.isEmpty ||
        scoreButtons.any((value) => value is! int || value <= 0)) {
      throw BackupValidationException(
        'Rule template ${template.id} has invalid score buttons.',
      );
    }
    final customEventMetadata = _decodeJson(
      'Rule template ${template.id} custom events',
      template.customEventTypesJson,
    );
    final customEvents = switch (customEventMetadata) {
      final List<dynamic> values => values,
      final Map<String, dynamic> metadata => metadata['eventTypes'],
      _ => null,
    };
    final possessionHint = customEventMetadata is Map<String, dynamic>
        ? customEventMetadata['possessionHintEnabled']
        : false;
    if (customEvents is! List<dynamic> ||
        customEvents.any((value) => value is! String || value.trim().isEmpty) ||
        possessionHint is! bool) {
      throw BackupValidationException(
        'Rule template ${template.id} has invalid custom event metadata.',
      );
    }
  }

  void _validateRuleJson(String label, Map<String, dynamic> rule) {
    final scoreButtons = rule['scoreButtons'];
    final customEvents = rule['customEventTypes'];
    final targetScore = rule['targetScore'];
    final timeLimit = rule['timeLimitSeconds'];
    final foulLimit = rule['foulLimit'];
    if (rule['id'] is! String ||
        (rule['id'] as String).trim().isEmpty ||
        rule['name'] is! String ||
        (rule['name'] as String).trim().isEmpty ||
        scoreButtons is! List<dynamic> ||
        scoreButtons.isEmpty ||
        scoreButtons.any((value) => value is! int || value <= 0) ||
        (targetScore != null && (targetScore is! int || targetScore <= 0)) ||
        (timeLimit != null && (timeLimit is! int || timeLimit <= 0)) ||
        rule['winByTwo'] is! bool ||
        (foulLimit != null && (foulLimit is! int || foulLimit <= 0)) ||
        rule['possessionHintEnabled'] is! bool ||
        customEvents is! List<dynamic> ||
        customEvents.any((value) => value is! String || value.trim().isEmpty)) {
      throw BackupValidationException('$label is invalid.');
    }
  }

  Object? _decodeJson(String label, String source) {
    try {
      return jsonDecode(source);
    } on Object catch (error) {
      throw BackupValidationException('$label is not valid JSON: $error');
    }
  }

  Map<String, dynamic> _decodeJsonObject(String label, String source) {
    final decoded = _decodeJson(label, source);
    if (decoded is! Map<String, dynamic>) {
      throw BackupValidationException('$label must be a JSON object.');
    }
    return decoded;
  }

  Set<String> _enumNames(Iterable<Enum> values) {
    return values.map((value) => value.name).toSet();
  }

  Set<String> _uniqueIds(String table, Iterable<String> ids) {
    final result = <String>{};
    for (final id in ids) {
      if (id.isEmpty || !result.add(id)) {
        throw BackupValidationException(
          '$table contains an empty or duplicate primary key.',
        );
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _rows<T extends DataClass>(
    TableInfo<Table, T> table, {
    String key = 'id',
    List<String>? sortKeys,
    bool sortByKey = true,
    bool Function(Map<String, dynamic> row)? include,
  }) async {
    final query = database.select(table);
    if (!sortByKey) {
      // Legacy chronology is represented by SQLite insertion order. Keep the
      // ordering in SQL because a SELECT without ORDER BY is not deterministic.
      query.orderBy([
        (_) => OrderingTerm(expression: const CustomExpression<int>('rowid')),
      ]);
    }
    final rows = await query.get();
    final json = rows
        .map((row) => row.toJson())
        .where((row) => include == null || include(row))
        .toList();
    if (sortByKey) {
      final keys = sortKeys ?? [key];
      json.sort((first, second) {
        for (final sortKey in keys) {
          final comparison = (first[sortKey] as String).compareTo(
            second[sortKey] as String,
          );
          if (comparison != 0) return comparison;
        }
        return 0;
      });
    }
    return json;
  }

  Future<void> _insertAll<T extends Object>(
    TableInfo<Table, T> table,
    Iterable<Insertable<T>> rows,
  ) async {
    for (final row in rows) {
      await database.into(table).insert(row);
    }
  }

  String _checksum(
    BackupManifest manifest,
    Map<String, List<Map<String, dynamic>>> data,
  ) {
    final encoded = jsonEncode({
      'manifest': manifest.checksumSourceJson(),
      'data': data,
    });
    return sha256.convert(utf8.encode(encoded)).toString();
  }
}
