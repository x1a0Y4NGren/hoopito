import 'package:hoopito/core/domain/domain_enums.dart';

/// Persisted clock projection; display time is reconstructed from this state
/// and [runningSinceUtc], rather than writing once per tick.
class ClockState {
  ClockState({
    required this.id,
    required this.matchId,
    required this.mode,
    required this.phase,
    required this.accumulatedSeconds,
    this.runningSinceUtc,
    this.regulationSeconds,
  }) {
    if (accumulatedSeconds < 0) {
      throw ArgumentError.value(
        accumulatedSeconds,
        'accumulatedSeconds',
        'must not be negative',
      );
    }
    if (regulationSeconds != null && regulationSeconds! < 0) {
      throw ArgumentError.value(
        regulationSeconds,
        'regulationSeconds',
        'must not be negative',
      );
    }
  }

  final String id;
  final String matchId;
  final ClockMode mode;
  final ClockPhase phase;
  final int accumulatedSeconds;
  final DateTime? runningSinceUtc;
  final int? regulationSeconds;

  bool get isRunning => runningSinceUtc != null;

  ClockState copyWith({
    String? id,
    String? matchId,
    ClockMode? mode,
    ClockPhase? phase,
    int? accumulatedSeconds,
    Object? runningSinceUtc = _clockStateUnset,
    Object? regulationSeconds = _clockStateUnset,
  }) {
    return ClockState(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      runningSinceUtc: identical(runningSinceUtc, _clockStateUnset)
          ? this.runningSinceUtc
          : runningSinceUtc as DateTime?,
      regulationSeconds: identical(regulationSeconds, _clockStateUnset)
          ? this.regulationSeconds
          : regulationSeconds as int?,
    );
  }

  int? get remainingSeconds {
    if (mode != ClockMode.countdown ||
        phase != ClockPhase.regulation ||
        regulationSeconds == null) {
      return null;
    }
    return (regulationSeconds! - accumulatedSeconds).clamp(
      0,
      regulationSeconds!,
    );
  }
}

const _clockStateUnset = Object();
