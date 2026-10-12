import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/core/domain/entities/player.dart';

import '../test_helpers/test_database.dart';

void main() {
  test('player profiles provider reflects repository stream updates', () async {
    final database = createTestDatabase();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final player = Player(
      id: 'player-provider',
      nickname: 'Provider Player',
      createdAt: DateTime.utc(2026, 8, 23),
    );
    // Start the stream before writing, matching the production route where
    // the provider is watched as the page is built. Drift's in-memory query
    // stream delivers the first non-empty projection after the write.
    final updated = Completer<List<Player>>();
    final subscription = container.listen(playerProfilesProvider, (
      previous,
      next,
    ) {
      final value = next.valueOrNull;
      if (value != null && value.isNotEmpty && !updated.isCompleted) {
        updated.complete(value);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);
    await container.read(playerRepositoryProvider).save(player);

    final players = await updated.future;
    expect(players, hasLength(1));
    expect(players.single.id, player.id);
    expect(players.single.nickname, player.nickname);
  });
}
