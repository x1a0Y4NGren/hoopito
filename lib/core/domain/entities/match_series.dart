import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

class SeriesStartContext {
  const SeriesStartContext({
    required this.seriesId,
    required this.expectedRevision,
    required this.gameNumber,
    this.slotASide = TeamSide.red,
    this.create = false,
  });
  final String seriesId;
  final int expectedRevision;
  final int gameNumber;
  final TeamSide slotASide;
  final bool create;
  Map<String, Object?> toJson() => {
    'seriesId': seriesId,
    'expectedRevision': expectedRevision,
    'gameNumber': gameNumber,
    'slotASide': slotASide.name,
    'create': create,
  };
}

class SeriesFailure implements Exception {
  const SeriesFailure(this.reason);
  final String reason;
  @override
  String toString() => 'SeriesFailure($reason)';
}

class SeriesGame {
  const SeriesGame({
    required this.matchId,
    required this.gameNumber,
    required this.slotASide,
    required this.detail,
  });
  final String matchId;
  final int gameNumber;
  final TeamSide slotASide;
  final MatchDetail detail;
  bool get completed =>
      detail.match.lifecycle == MatchLifecycle.finished ||
      detail.match.lifecycle == MatchLifecycle.archived;
  int get slotAScore =>
      slotASide == TeamSide.red ? detail.redScore : detail.blueScore;
  int get slotBScore =>
      slotASide == TeamSide.red ? detail.blueScore : detail.redScore;
}

class MatchSeries {
  const MatchSeries({
    required this.id,
    required this.slotAName,
    required this.slotBName,
    required this.slotAPlayerProfileId,
    required this.slotBPlayerProfileId,
    required this.isOpen,
    required this.revision,
    required this.nextGameNumber,
    required this.createdAt,
    required this.closedAt,
    required this.defaultSetup,
    required this.games,
  });
  final String id, slotAName, slotBName;
  final String? slotAPlayerProfileId, slotBPlayerProfileId;
  final bool isOpen;
  final int revision, nextGameNumber;
  final DateTime createdAt;
  final DateTime? closedAt;
  final Map<String, dynamic> defaultSetup;
  final List<SeriesGame> games;
  int get completedGames => games.where((g) => g.completed).length;
  int get slotAWins =>
      games.where((g) => g.completed && g.slotAScore > g.slotBScore).length;
  int get slotBWins =>
      games.where((g) => g.completed && g.slotBScore > g.slotAScore).length;
  int get draws =>
      games.where((g) => g.completed && g.slotAScore == g.slotBScore).length;
}
