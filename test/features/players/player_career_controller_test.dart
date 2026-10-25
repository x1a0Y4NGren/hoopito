import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/analytics/player_career_aggregate.dart';
import 'package:hoopito/features/players/player_career_controller.dart';

void main() {
  test('a stale career stream cannot overwrite the latest query', () async {
    late void Function(PlayerCareerAggregate) emitFirst;
    late void Function(PlayerCareerAggregate) emitSecond;
    var loadCount = 0;
    final controller = PlayerCareerController(
      playerId: 'p1',
      loader: (_) {
        loadCount++;
        return _LateDeliveryStream(
          onListen: (emit) {
            if (loadCount == 1) {
              emitFirst = emit;
            } else {
              emitSecond = emit;
            }
          },
        );
      },
    );
    addTearDown(controller.dispose);

    controller.setWindow(PlayerCareerWindow.sevenDays);
    emitSecond(const PlayerCareerAggregate.empty('latest'));
    emitFirst(const PlayerCareerAggregate.empty('stale'));

    expect(controller.aggregate?.playerId, 'latest');
    expect(controller.query.window, PlayerCareerWindow.sevenDays);
  });
}

/// Simulates a source whose already-scheduled callback arrives after cancel.
class _LateDeliveryStream extends Stream<PlayerCareerAggregate> {
  _LateDeliveryStream({required this.onListen});

  final void Function(void Function(PlayerCareerAggregate) emit) onListen;

  @override
  StreamSubscription<PlayerCareerAggregate> listen(
    void Function(PlayerCareerAggregate event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    onListen((value) => onData?.call(value));
    return const _NoopSubscription();
  }
}

class _NoopSubscription implements StreamSubscription<PlayerCareerAggregate> {
  const _NoopSubscription();

  @override
  Future<void> cancel() async {}

  @override
  void onData(void Function(PlayerCareerAggregate data)? handleData) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) => Future<E>.value(futureValue);
}
