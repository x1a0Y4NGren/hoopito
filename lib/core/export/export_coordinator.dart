import 'dart:convert';
import 'dart:typed_data';

import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/backup_merge_service.dart';
import 'package:hoopito/core/export/csv_exporter.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/export/safety_backup_store.dart';

export 'package:hoopito/core/export/json_backup_codec.dart'
    show BackupRestoreBlockedException;
export 'package:hoopito/core/export/safety_backup_store.dart';

class ExportArtifact {
  const ExportArtifact({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  factory ExportArtifact.text({
    required String fileName,
    required String mimeType,
    required String contents,
  }) {
    return ExportArtifact(
      fileName: fileName,
      mimeType: mimeType,
      bytes: Uint8List.fromList(utf8.encode(contents)),
    );
  }

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
}

abstract interface class ExportGateway {
  Future<void> share(List<ExportArtifact> artifacts, {required String subject});

  Future<ExportArtifact?> pickBackup({String? dialogTitle});

  Future<BackupDirectorySelection?> pickDirectory({String? dialogTitle});
}

class ExportCoordinator {
  ExportCoordinator(
    this.database,
    this.codec, {
    required this.gateway,
    required this.automaticBackup,
    SafetyBackupStore? safetyBackups,
    BackupMergeService? mergeService,
    DateTime Function()? now,
  }) : safetyBackups = safetyBackups ?? SafetyBackupStore(codec),
       mergeService =
           mergeService ?? BackupMergeService.withCodec(database, codec: codec),
       now = now ?? DateTime.now;

  final AppDatabase database;
  final JsonBackupCodec codec;
  final ExportGateway gateway;
  final AutomaticBackupService automaticBackup;
  final SafetyBackupStore safetyBackups;
  final BackupMergeService mergeService;
  final DateTime Function() now;

  Future<void> shareJsonBackup({required String subject}) async {
    final timestamp = now().toUtc();
    final payload = await codec.export();
    await gateway.share([
      ExportArtifact.text(
        fileName: 'hoopito-backup-${_fileTimestamp(timestamp)}.json',
        mimeType: 'application/json',
        contents: payload,
      ),
    ], subject: subject);
  }

  Future<bool> restorePickedBackup({
    RestoreMode mode = RestoreMode.replace,
    String? safetySubject,
    String? pickerDialogTitle,
  }) async {
    if (mode == RestoreMode.replace) await _throwIfReplacementBlocked();
    final artifact = await gateway.pickBackup(dialogTitle: pickerDialogTitle);
    if (artifact == null) return false;
    final payload = utf8.decode(artifact.bytes, allowMalformed: false);
    if (mode == RestoreMode.merge) {
      final result = await mergeService.merge(payload);
      if (result.changed) await automaticBackup.markDirty();
      return true;
    }
    codec.validate(payload);
    await _replaceWithSafetyBackup(payload);
    return true;
  }

  Future<List<SafetyBackup>> listSafetyBackups() async =>
      (await safetyBackups.list())
          .take(SafetyBackupStore.retentionLimit)
          .toList(growable: false);

  Future<void> restoreSafetyBackup(SafetyBackup backup) async {
    await _throwIfReplacementBlocked();
    final payload = await safetyBackups.read(backup);
    await _replaceWithSafetyBackup(payload);
  }

  Future<void> _replaceWithSafetyBackup(String payload) async {
    await database.transaction(() async {
      // A zero-row UPDATE obtains SQLite's write reservation without changing
      // user data or firing row triggers. Keep the reservation across snapshot
      // capture, file flush/readback/publication and replacement, including for
      // other engines connected to this database.
      await database.customStatement(
        'UPDATE app_settings SET key = key WHERE 0',
      );
      await _throwIfReplacementBlocked();
      await safetyBackups.save(await codec.export());
      await codec.restore(payload);
      await automaticBackup.resetAfterRestore();
    });
    try {
      await safetyBackups.retainLatest();
    } on Object {
      // A cleanup failure must not report an already committed restore as
      // failed. Extra valid snapshots remain available until later cleanup.
    }
  }

  Future<void> _throwIfReplacementBlocked() async {
    final hasActiveSession =
        (await database.select(database.activeSessions).get()).isNotEmpty;
    if (hasActiveSession) throw const BackupRestoreBlockedException();
  }

  Future<void> shareCsvExports({required String subject}) async {
    final timestamp = now().toUtc();
    final matches = await database.select(database.matches).get();
    final events = await database.select(database.matchEvents).get();
    final players = await database.select(database.players).get();
    final participants = await database
        .select(database.matchParticipants)
        .get();
    final statistics = _buildPlayerStatistics(
      matches,
      events,
      players,
      participants,
    );
    final suffix = _fileTimestamp(timestamp);
    await gateway.share([
      ExportArtifact.text(
        fileName: 'hoopito-matches-$suffix.csv',
        mimeType: 'text/csv',
        contents: CsvExporter.matchList(matches, participants: participants),
      ),
      ExportArtifact.text(
        fileName: 'hoopito-events-$suffix.csv',
        mimeType: 'text/csv',
        contents: CsvExporter.eventList(events),
      ),
      ExportArtifact.text(
        fileName: 'hoopito-player-stats-$suffix.csv',
        mimeType: 'text/csv',
        contents: CsvExporter.playerStatistics(statistics),
      ),
    ], subject: subject);
  }

  Future<void> shareReplayImage(
    Uint8List bytes, {
    required String matchId,
    required String subject,
  }) {
    final safeMatchId = _safeFilePart(matchId);
    return gateway.share([
      ExportArtifact(
        fileName: 'hoopito-replay-$safeMatchId.png',
        mimeType: 'image/png',
        bytes: bytes,
      ),
    ], subject: subject);
  }

  Future<BackupDirectorySelection?> pickBackupDirectory({
    String? dialogTitle,
  }) => gateway.pickDirectory(dialogTitle: dialogTitle);

  static List<PlayerStatisticsRow> _buildPlayerStatistics(
    List<Matche> matches,
    List<MatchEventRow> events,
    List<PlayerRow> players,
    List<MatchParticipant> matchParticipants,
  ) {
    final completedMatches = matches
        .where(
          (match) =>
              match.lifecycle == 'finished' || match.lifecycle == 'archived',
        )
        .toList(growable: false);
    final completedIds = completedMatches.map((match) => match.id).toSet();
    final participants = <_Participant>[
      for (final player in players)
        _Participant(id: player.id, name: player.nickname),
      for (final participant in matchParticipants)
        if (participant.playerProfileId == null &&
            completedIds.contains(participant.matchId))
          _Participant(
            id: '',
            name: participant.nameSnapshot,
            matchId: participant.matchId,
            participantId: participant.id,
          ),
    ];

    final eventsByMatch = <String, List<MatchEvent>>{};
    for (final event in events.where((event) => !event.isDeleted)) {
      eventsByMatch
          .putIfAbsent(event.matchId, () => [])
          .add(
            MatchEvent(
              id: event.id,
              matchId: event.matchId,
              type: EventKind.values.byName(event.type),
              side: event.side == null
                  ? null
                  : TeamSide.values.byName(event.side!),
              points: event.points,
              occurredAt: event.occurredAt,
              outcome: event.outcome == null
                  ? null
                  : ShotOutcome.values.byName(event.outcome!),
              note: event.note,
              customLabel: event.customLabel,
              matchClockPositionSeconds: event.matchClockPositionSeconds,
            ),
          );
    }
    final calculator = MatchAnalyticsCalculator();
    final scoresByMatch = {
      for (final match in completedMatches)
        match.id: calculator
            .calculate(eventsByMatch[match.id] ?? const [])
            .scoringFlow
            .lastOrNull,
    };

    return participants
        .map((participant) {
          var matchesPlayed = 0;
          var wins = 0;
          var points = 0;
          var fieldGoalMade = 0;
          var fieldGoalAttempts = 0;
          var freeThrowMade = 0;
          var freeThrowAttempts = 0;
          var attemptsComplete = true;
          for (final match in completedMatches) {
            final sides = <TeamSide>{
              for (final matchParticipant in matchParticipants)
                if (matchParticipant.matchId == match.id &&
                    (participant.id.isNotEmpty
                        ? matchParticipant.playerProfileId == participant.id
                        : matchParticipant.id == participant.participantId &&
                              matchParticipant.matchId == participant.matchId))
                  TeamSide.values.byName(matchParticipant.side),
            };
            if (sides.isEmpty) continue;
            matchesPlayed++;
            final matchEvents = eventsByMatch[match.id] ?? const [];
            final coverage = TrackingCoverage.values.byName(
              match.trackingCoverage,
            );
            final analytics = calculator.calculate(
              matchEvents
                  .where((event) => sides.contains(event.side))
                  .toList(growable: false),
              trackingCoverage: coverage,
            );
            final score = analytics.scoringFlow.lastOrNull;
            points += (score?.redScore ?? 0) + (score?.blueScore ?? 0);
            fieldGoalMade += analytics.fieldGoalMadeCount;
            fieldGoalAttempts += analytics.fieldGoalAttemptCount;
            freeThrowMade += analytics.freeThrowMadeCount;
            freeThrowAttempts += analytics.freeThrowAttemptCount;
            attemptsComplete =
                attemptsComplete &&
                coverage.index >= TrackingCoverage.shotAttempts.index;
            final allScores = scoresByMatch[match.id];
            final redScore = allScores?.redScore ?? 0;
            final blueScore = allScores?.blueScore ?? 0;
            if ((sides.contains(TeamSide.red) && redScore > blueScore) ||
                (sides.contains(TeamSide.blue) && blueScore > redScore)) {
              wins++;
            }
          }
          return PlayerStatisticsRow(
            playerId: participant.id,
            playerName: participant.name,
            matchesPlayed: matchesPlayed,
            wins: wins,
            points: points,
            matchId: participant.matchId,
            participantId: participant.participantId,
            fieldGoalMade: fieldGoalMade,
            fieldGoalAttempts: fieldGoalAttempts,
            freeThrowMade: freeThrowMade,
            freeThrowAttempts: freeThrowAttempts,
            attemptsComplete: attemptsComplete,
          );
        })
        .toList(growable: false);
  }

  static String _safeFilePart(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return sanitized.isEmpty ? 'match' : sanitized;
  }

  static String _fileTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}'
        '${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}

class _Participant {
  const _Participant({
    required this.id,
    required this.name,
    this.matchId = '',
    this.participantId = '',
  });

  final String id;
  final String name;
  final String matchId;
  final String participantId;
}
