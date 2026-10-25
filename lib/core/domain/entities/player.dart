import 'package:hoopito/core/domain/value_objects/team_side.dart';

class Player {
  const Player({
    required this.id,
    required this.nickname,
    required this.createdAt,
    this.preferredSide,
    this.note,
  });

  final String id;
  final String nickname;
  final DateTime createdAt;
  final TeamSide? preferredSide;
  final String? note;
}
