import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/clock_state.dart';
import 'package:hoopito/core/domain/clock/clock_engine.dart';

void main() {
  final anchor = DateTime.utc(2026, 8, 23, 10);

  test(
    'count-up projection derives elapsed seconds from a persisted anchor',
    () {
      final projection = ClockEngine().project(
        state: ClockState(
          id: 'clock-1',
          matchId: 'match-1',
          mode: ClockMode.countUp,
          phase: ClockPhase.regulation,
          accumulatedSeconds: 17,
          runningSinceUtc: anchor,
        ),
        now: anchor.add(const Duration(seconds: 12, milliseconds: 999)),
      );

      expect(projection.elapsedSeconds, 29);
      expect(projection.displaySeconds, 29);
      expect(projection.isRunning, isTrue);
      expect(projection.recoveryReason, isNull);
    },
  );

  test(
    'countdown freezes at the exact zero boundary as regulation expired',
    () {
      final projection = ClockEngine().project(
        state: ClockState(
          id: 'clock-2',
          matchId: 'match-2',
          mode: ClockMode.countdown,
          phase: ClockPhase.regulation,
          accumulatedSeconds: 3,
          runningSinceUtc: anchor,
          regulationSeconds: 10,
        ),
        now: anchor.add(const Duration(seconds: 7)),
      );

      expect(projection.elapsedSeconds, 10);
      expect(projection.displaySeconds, 0);
      expect(projection.phase, ClockPhase.regulationExpired);
      expect(projection.isRunning, isFalse);
      expect(projection.requiresPersistence, isTrue);
    },
  );

  test(
    'backward wall-clock projection clamps elapsed and requests recovery pause',
    () {
      final projection = ClockEngine().project(
        state: ClockState(
          id: 'clock-3',
          matchId: 'match-3',
          mode: ClockMode.countUp,
          phase: ClockPhase.regulation,
          accumulatedSeconds: 42,
          runningSinceUtc: anchor,
        ),
        now: anchor.subtract(const Duration(seconds: 1)),
      );

      expect(projection.elapsedSeconds, 42);
      expect(projection.displaySeconds, 42);
      expect(
        projection.recoveryReason,
        ClockRecoveryReason.wallClockMovedBackward,
      );
      expect(projection.requiresPersistence, isTrue);
      expect(projection.isRunning, isFalse);
      expect(projection.recoveryMessage, isNotEmpty);
    },
  );

  test('overtime projection is count-up from a zeroed persisted clock', () {
    final state = ClockState(
      id: 'clock-4',
      matchId: 'match-4',
      mode: ClockMode.countdown,
      phase: ClockPhase.overtime,
      accumulatedSeconds: 0,
      runningSinceUtc: anchor,
      regulationSeconds: 10,
    );
    final projection = ClockEngine().project(
      state: state,
      now: anchor.add(const Duration(seconds: 4)),
    );

    expect(projection.phase, ClockPhase.overtime);
    expect(projection.elapsedSeconds, 4);
    expect(projection.displaySeconds, 4);
    expect(projection.remainingSeconds, isNull);
    expect(state.remainingSeconds, isNull);
  });
}
