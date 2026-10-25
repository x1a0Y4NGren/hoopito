import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/csv_exporter.dart';

void main() {
  group('CsvExporter', () {
    test('exports match list with stable headers and escaped text', () {
      final encoded = CsvExporter.matchList(
        [
          Matche(
            id: 'match-1',
            lifecycle: 'finished',
            recordingMode: 'simple',
            trackingCoverage: 'scoresOnly',
            ruleTemplateJson: '{}',
            createdAt: DateTime.utc(2026, 7, 18, 8),
            startedAt: DateTime.utc(2026, 7, 18, 8, 1),
            endedAt: DateTime.utc(2026, 7, 18, 8, 9),
            timerEnabled: false,
            note: 'line one\nline two',
          ),
        ],
        participants: const [
          MatchParticipant(
            id: 'participant-red',
            matchId: 'match-1',
            side: 'red',
            nameSnapshot: 'Red, Prime',
          ),
          MatchParticipant(
            id: 'participant-blue',
            matchId: 'match-1',
            side: 'blue',
            nameSnapshot: 'Blue "Wave"',
          ),
        ],
      );

      final rows = _decodeCsv(encoded);
      expect(rows.first, CsvExporter.matchHeaders);
      expect(rows.singleWhere((row) => row.first == 'match-1'), [
        'match-1',
        'Red, Prime',
        'Blue "Wave"',
        'finished',
        '2026-07-18T08:00:00.000Z',
        '2026-07-18T08:01:00.000Z',
        '2026-07-18T08:09:00.000Z',
        'false',
        'line one\nline two',
      ]);
      expect(encoded, contains('"Red, Prime"'));
      expect(encoded, contains('"Blue ""Wave"""'));
      expect(encoded, contains('"line one\nline two"'));
    });

    test('exports required event fields with stable headers', () {
      final encoded = CsvExporter.eventList([
        MatchEventRow(
          id: 'event-1',
          matchId: 'match-1',
          type: 'score',
          side: 'red',
          points: 3,
          occurredAt: DateTime.utc(2026, 7, 18, 8, 2, 3),
          outcome: null,
          matchClockPositionSeconds: null,
          note: 'deep, corner',
          customLabel: null,
          isDeleted: false,
        ),
      ]);

      final rows = _decodeCsv(encoded);
      expect(rows.first, CsvExporter.eventHeaders);
      expect(rows[1].take(6), [
        'match-1',
        'event-1',
        'score',
        'red',
        3,
        '2026-07-18T08:02:03.000Z',
      ]);
      expect(rows[1][6], 'deep, corner');
    });

    test('exports player statistics with stable headers', () {
      final encoded = CsvExporter.playerStatistics([
        const PlayerStatisticsRow(
          playerId: 'player-1',
          playerName: 'A, Ace',
          matchesPlayed: 4,
          wins: 3,
          points: 28,
          fieldGoalMade: 12,
          fieldGoalAttempts: 20,
          freeThrowMade: 4,
          freeThrowAttempts: 5,
          attemptsComplete: true,
        ),
      ]);

      final rows = _decodeCsv(encoded);
      expect(rows.first, CsvExporter.playerStatisticsHeaders);
      expect(rows[1], [
        'player-1',
        'A, Ace',
        '',
        '',
        4,
        3,
        28,
        12,
        20,
        60.0,
        4,
        5,
        80.0,
      ]);
      expect(encoded, endsWith(',80.00'));
    });

    test('incomplete and zero samples export empty percentage cells', () {
      final rows = _decodeCsv(
        CsvExporter.playerStatistics([
          const PlayerStatisticsRow(
            playerId: 'incomplete',
            playerName: 'Incomplete',
            matchesPlayed: 1,
            wins: 1,
            points: 7,
            fieldGoalMade: 2,
            fieldGoalAttempts: 3,
            freeThrowMade: 3,
            freeThrowAttempts: 4,
            attemptsComplete: false,
          ),
          const PlayerStatisticsRow(
            playerId: 'zero',
            playerName: 'Zero',
            matchesPlayed: 1,
            wins: 0,
            points: 0,
            fieldGoalMade: 0,
            fieldGoalAttempts: 0,
            freeThrowMade: 0,
            freeThrowAttempts: 0,
            attemptsComplete: true,
          ),
        ]),
      );
      expect(rows[1].skip(7), [2, 3, '', 3, 4, '']);
      expect(rows[2].skip(7), [0, 0, '', 0, 0, '']);
    });
  });
}

List<List<dynamic>> _decodeCsv(String encoded) {
  return Csv(
    dynamicTyping: true,
    decoderTransform: (field, _, _) => field is bool ? field.toString() : field,
  ).decode(encoded);
}
