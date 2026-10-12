import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/clock_state.dart';

/// Why a running clock was stopped while reconstructing its projection.
enum ClockRecoveryReason { wallClockMovedBackward }

/// A deterministic display projection of a persisted [ClockState].
///
/// The database stores only an accumulated whole-second value and an optional
/// UTC anchor. Callers can reconstruct this value after process death without
/// a timer or a per-tick database write. [normalizedState] is the state that
/// should be persisted when [requiresPersistence] is true (for example when a
/// countdown reaches zero or the wall clock moves backward).
class ClockProjection {
  const ClockProjection({
    required this.state,
    required this.normalizedState,
    required this.nowUtc,
    required this.elapsedSeconds,
    required this.displaySeconds,
    required this.phase,
    required this.remainingSeconds,
    required this.recoveryReason,
    required this.recoveryMessage,
    required this.requiresPersistence,
  });

  final ClockState state;
  final ClockState normalizedState;
  final DateTime nowUtc;
  final int elapsedSeconds;
  final int displaySeconds;
  final ClockPhase phase;
  final int? remainingSeconds;
  final ClockRecoveryReason? recoveryReason;
  final String? recoveryMessage;
  final bool requiresPersistence;

  bool get isRunning =>
      normalizedState.runningSinceUtc != null &&
      recoveryReason == null &&
      phase != ClockPhase.regulationExpired;

  bool get isRegulationExpired => phase == ClockPhase.regulationExpired;

  DateTime? get runningSinceUtc => normalizedState.runningSinceUtc;
}

/// Pure clock arithmetic used by repositories and command transactions.
class ClockEngine {
  const ClockEngine();

  ClockProjection project({required ClockState state, required DateTime now}) {
    final nowUtc = now.toUtc();
    final anchor = state.runningSinceUtc?.toUtc();
    final movedBackward = anchor != null && nowUtc.isBefore(anchor);
    final deltaSeconds = movedBackward || anchor == null
        ? 0
        : nowUtc.difference(anchor).inSeconds;
    var elapsed = state.accumulatedSeconds + deltaSeconds;
    var phase = state.phase;
    var runningSince = anchor;
    var requiresPersistence = false;

    if (movedBackward) {
      runningSince = null;
      requiresPersistence = true;
    }

    if (state.mode == ClockMode.countdown &&
        phase == ClockPhase.regulation &&
        state.regulationSeconds != null &&
        elapsed >= state.regulationSeconds!) {
      elapsed = state.regulationSeconds!;
      phase = ClockPhase.regulationExpired;
      runningSince = null;
      requiresPersistence = true;
    }

    if (phase == ClockPhase.regulationExpired) {
      runningSince = null;
      if (state.regulationSeconds != null) {
        elapsed = state.regulationSeconds!;
      }
    }

    final displaySeconds =
        state.mode == ClockMode.countdown && phase == ClockPhase.regulation
        ? (state.regulationSeconds == null
              ? elapsed
              : (state.regulationSeconds! - elapsed).clamp(
                  0,
                  state.regulationSeconds!,
                ))
        : phase == ClockPhase.regulationExpired
        ? 0
        : elapsed;
    final remainingSeconds =
        state.mode == ClockMode.countdown &&
            phase == ClockPhase.regulation &&
            state.regulationSeconds != null
        ? (state.regulationSeconds! - elapsed).clamp(
            0,
            state.regulationSeconds!,
          )
        : null;

    final recoveryReason = movedBackward
        ? ClockRecoveryReason.wallClockMovedBackward
        : null;
    final normalizedState = state.copyWith(
      phase: phase,
      accumulatedSeconds: elapsed,
      runningSinceUtc: runningSince,
    );

    return ClockProjection(
      state: state,
      normalizedState: normalizedState,
      nowUtc: nowUtc,
      elapsedSeconds: elapsed,
      displaySeconds: displaySeconds,
      phase: phase,
      remainingSeconds: remainingSeconds,
      recoveryReason: recoveryReason,
      recoveryMessage: recoveryReason == null
          ? null
          : 'The clock was paused because the device clock moved backward.',
      requiresPersistence: requiresPersistence,
    );
  }
}

/// Compatibility name for callers that describe the object as a match clock.
typedef MatchClockEngine = ClockEngine;
