import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'player repository creates, updates, watches and deletes players',
    () async {
      final database = createTestDatabase();
      final repository = PlayerRepository(database);
      final emissions = <List<Player>>[];
      final subscription = repository.watchAll().listen(emissions.add);
      addTearDown(subscription.cancel);

      await repository.save(
        Player(
          id: 'player-1',
          nickname: '阿岚',
          createdAt: DateTime.utc(2026, 7, 10),
          preferredSide: TeamSide.red,
          note: '擅长突破',
        ),
      );
      final created = await repository.getById('player-1');
      expect(created?.nickname, '阿岚');
      expect(created?.preferredSide, TeamSide.red);

      await repository.save(
        Player(
          id: 'player-1',
          nickname: '阿岚 7',
          createdAt: created!.createdAt,
          preferredSide: TeamSide.blue,
          note: '左侧底角',
        ),
      );
      expect((await repository.getById('player-1'))?.nickname, '阿岚 7');

      await repository.delete('player-1');
      expect(await repository.getById('player-1'), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(emissions.any((players) => players.isNotEmpty), isTrue);
      expect(emissions.last, isEmpty);
    },
  );
}
