import 'dart:developer' as developer;

/// In-memory preparation spans for opt-in Profile startup diagnostics.
/// Normal builds do not read the clock, collect records, or emit output.
abstract final class StartupDiagnostics {
  static const enabled =
      bool.fromEnvironment('dart.vm.profile') &&
      bool.fromEnvironment('HOOPITO_ENTRY_PROFILE');

  static final _spans = <Map<String, Object>>[];
  static var _finished = false;

  static int? start() => enabled && !_finished ? developer.Timeline.now : null;

  static void end(String stage, int? startedAt) {
    if (startedAt == null || _finished) return;
    final endedAt = developer.Timeline.now;
    _spans.add({
      'stage': stage,
      'started_at_us': startedAt,
      'ended_at_us': endedAt,
      'elapsed_us': endedAt - startedAt,
    });
  }

  static T measureSync<T>(String stage, T Function() action) {
    if (!enabled || _finished) return action();
    final startedAt = start();
    try {
      return action();
    } finally {
      end(stage, startedAt);
    }
  }

  static List<Map<String, Object>> takeSpans() {
    _finished = true;
    final result = List<Map<String, Object>>.of(_spans);
    _spans.clear();
    return result;
  }

  static void stop() {
    _finished = true;
    _spans.clear();
  }
}
