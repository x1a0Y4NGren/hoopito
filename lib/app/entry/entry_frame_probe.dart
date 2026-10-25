import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:hoopito/core/diagnostics/startup_diagnostics.dart';

/// Opt-in diagnostics for a Profile build. No callbacks or output in normal
/// builds, and no filesystem, database, or network access.
class EntryFrameProbe {
  EntryFrameProbe() {
    if (!_enabled) return;
    _startedAt = developer.Timeline.now;
    _registered = true;
    SchedulerBinding.instance.addTimingsCallback(_collect);
    mark('initializing');
  }

  static const _enabled =
      kProfileMode && bool.fromEnvironment('HOOPITO_ENTRY_PROFILE');
  static const _prefix = 'HOOPITO_ENTRY_PROFILE_JSON ';
  static const _flushDelay = Duration(milliseconds: 1200);

  final _frames = <FrameTiming>[];
  final _marks = <Map<String, Object>>[];
  final _preparation = <String, Object>{};
  int _startedAt = 0;
  bool _registered = false;
  bool _disposed = false;
  Timer? _flushTimer;
  Completer<void>? _completion;

  void _collect(List<FrameTiming> frames) => _frames.addAll(frames);

  void mark(String phase) {
    if (!_enabled || _disposed || _completion != null) return;
    _marks.add({'phase': phase, 'time_us': developer.Timeline.now});
  }

  void preparation(
    String stage, {
    required int elapsedUs,
    required String outcome,
  }) {
    if (!_enabled || _disposed || _completion != null) return;
    _preparation[stage] = {'elapsed_us': elapsedUs, 'outcome': outcome};
  }

  /// Keep the callback alive after the last visual frame so the engine's
  /// batched timings arrive. Emit individual JSON records to avoid Android's
  /// per-log-line size limit; the summary is the final completion signal.
  Future<void> finish() {
    if (!_enabled || _disposed) return Future<void>.value();
    if (_completion != null) return _completion!.future;
    if (_marks.isEmpty || _marks.last['phase'] != 'finished') mark('finished');
    final completion = _completion = Completer<void>();
    _flushTimer = Timer(_flushDelay, () {
      _unregister();
      for (final span in StartupDiagnostics.takeSpans()) {
        _emit({'type': 'preparation_span', ...span});
      }
      for (var index = 0; index < _frames.length; index++) {
        final frame = _frames[index];
        _emit({
          'type': 'frame',
          'index': index,
          'frame_number': frame.frameNumber,
          'build_start_us': frame.timestampInMicroseconds(
            FramePhase.buildStart,
          ),
          'build_us': frame.buildDuration.inMicroseconds,
          'raster_us': frame.rasterDuration.inMicroseconds,
          'total_us': frame.totalSpan.inMicroseconds,
        });
      }
      _emit({
        'type': 'summary',
        'schema': 1,
        'profile': kProfileMode,
        'diagnostic': _enabled,
        'started_at_us': _startedAt,
        'marks': _marks,
        'preparation': _preparation,
        'frame_count': _frames.length,
        'flush_ms': _flushDelay.inMilliseconds,
      });
      _frames.clear();
      _flushTimer = null;
      completion.complete();
    });
    return completion.future;
  }

  void _emit(Map<String, Object> record) {
    debugPrintSynchronously('$_prefix${jsonEncode(record)}');
  }

  void _unregister() {
    if (!_registered) return;
    SchedulerBinding.instance.removeTimingsCallback(_collect);
    _registered = false;
  }

  /// An unfinished gate contributes no partial success record. A finished
  /// probe owns its short flush interval even if the gate is removed.
  void dispose() {
    if (_completion != null) return;
    StartupDiagnostics.stop();
    _disposed = true;
    _flushTimer?.cancel();
    _unregister();
    _frames.clear();
  }
}
