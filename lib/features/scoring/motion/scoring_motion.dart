import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:lottie/lottie.dart';

/// Presentation policy for a scoring hero. It intentionally has no persistence
/// or controller dependency, so a dropped frame cannot affect a score commit.
enum ScoringMotionMode { standard, reduced, disabled }

class ScoringMotionEvent {
  const ScoringMotionEvent({
    required this.receipt,
    Offset? sourceButton,
    Offset? sourceButtonCoordinate,
    required this.courtBounds,
    required this.safeWorkspace,
    this.sourceIdentity,
    this.geometryAvailable = true,
    this.assetAvailable = true,
  }) : assert(
         sourceButton != null || sourceButtonCoordinate != null,
         'A score-button coordinate is required for a motion event.',
       ),
       sourceButton = sourceButton ?? sourceButtonCoordinate ?? Offset.zero;

  final ShotLocationCommitReceipt receipt;
  final Offset sourceButton;
  Offset get sourceButtonCoordinate => sourceButton;
  final Rect courtBounds;
  final Rect safeWorkspace;
  final String? sourceIdentity;
  final bool geometryAvailable;
  final bool assetAvailable;

  String get id => receipt.eventId;
  String get locationId => receipt.shotLocationId;
  String get stableSourceIdentity =>
      sourceIdentity ?? '${receipt.side.name}:${receipt.points}';

  Offset get destination => Offset(
    courtBounds.left + (receipt.point.x * courtBounds.width),
    courtBounds.top + (receipt.point.y * courtBounds.height),
  );

  ScoringMotionPath get path => ScoringMotionPath.build(
    source: sourceButton,
    destination: destination,
    safeWorkspace: safeWorkspace,
  );
}

class ScoringMotionPath {
  ScoringMotionPath._({
    required this.source,
    required this.destination,
    required this.control1,
    required this.control2,
    required this.safeWorkspace,
    required ui.Path path,
  }) : _path = path;

  final Offset source;
  final Offset destination;
  final Offset control1;
  final Offset control2;
  final Rect safeWorkspace;
  final ui.Path _path;

  static ScoringMotionPath build({
    required Offset source,
    required Offset destination,
    required Rect safeWorkspace,
  }) {
    final distance = (destination - source).distance;
    final arc = (distance * .14).clamp(32.0, 96.0).toDouble();
    final topRoom = math.min(source.dy, destination.dy) - safeWorkspace.top;
    Offset c1;
    Offset c2;
    if (topRoom >= arc) {
      c1 = Offset(source.dx, source.dy - arc);
      c2 = Offset(destination.dx, destination.dy - arc);
    } else {
      final leftRoom = math.min(source.dx, destination.dx) - safeWorkspace.left;
      final rightRoom =
          safeWorkspace.right - math.max(source.dx, destination.dx);
      final direction = rightRoom >= leftRoom ? 1.0 : -1.0;
      c1 = source + Offset(direction * arc, 0);
      c2 = destination + Offset(direction * arc, 0);
    }
    c1 = _clampOffset(c1, safeWorkspace);
    c2 = _clampOffset(c2, safeWorkspace);
    final path = ui.Path()
      ..moveTo(source.dx, source.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, destination.dx, destination.dy);
    return ScoringMotionPath._(
      source: source,
      destination: destination,
      control1: c1,
      control2: c2,
      safeWorkspace: safeWorkspace,
      path: path,
    );
  }

  static ScoringMotionPath calculate({
    required Offset source,
    required Offset destination,
    required Rect safeWorkspace,
  }) => build(
    source: source,
    destination: destination,
    safeWorkspace: safeWorkspace,
  );

  ui.Path get path => _path;

  ScoringMotionSample sample(double progress) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    final metric = _path.computeMetrics().first;
    final distance = metric.length * p;
    final tangent = metric.getTangentForOffset(distance);
    final resolved = tangent ?? ui.Tangent(destination, destination - source);
    final count = math.max(1, math.min(6, (p * 12).ceil()));
    final trail = <ScoringTrailNode>[];
    for (var i = 0; i < count; i++) {
      final trailProgress = (p - (i * .045)).clamp(0.0, 1.0).toDouble();
      final trailTangent = metric.getTangentForOffset(
        metric.length * trailProgress,
      );
      trail.add(
        ScoringTrailNode(
          position: trailTangent?.position ?? resolved.position,
          opacity: math.max(.06, .48 * (1 - (i / count))),
        ),
      );
    }
    return ScoringMotionSample(
      position: resolved.position,
      tangent: resolved,
      trail: List.unmodifiable(trail),
    );
  }
}

Offset _clampOffset(Offset point, Rect bounds) => Offset(
  point.dx.clamp(bounds.left, bounds.right).toDouble(),
  point.dy.clamp(bounds.top, bounds.bottom).toDouble(),
);

class ScoringMotionSample {
  const ScoringMotionSample({
    required this.position,
    required this.tangent,
    required this.trail,
  });

  final Offset position;
  final ui.Tangent tangent;
  final List<ScoringTrailNode> trail;
}

class ScoringTrailNode {
  const ScoringTrailNode({required this.position, required this.opacity});

  final Offset position;
  final double opacity;
}

class ScoringMotionTiming {
  const ScoringMotionTiming({required this.flight, required this.impact});

  final Duration flight;
  final Duration impact;
  Duration get total => flight + impact;
}

class ScoringActiveMotion {
  ScoringActiveMotion({
    required this.event,
    required this.timing,
    this.mode = ScoringMotionMode.standard,
  });

  final ScoringMotionEvent event;
  final ScoringMotionTiming timing;
  final ScoringMotionMode mode;
  Duration elapsed = Duration.zero;
  bool impactDispatched = false;

  bool get isColorReveal => mode == ScoringMotionMode.reduced;
  bool get travelEnabled => mode == ScoringMotionMode.standard;
  bool get trailEnabled => travelEnabled && !inImpact;
  bool get particlesEnabled => travelEnabled && inImpact;
  double get colorRevealProgress => isColorReveal
      ? (elapsed.inMicroseconds / timing.total.inMicroseconds)
            .clamp(0.0, 1.0)
            .toDouble()
      : 1;
  String get assetName => inImpact
      ? 'assets/animations/paint_splash.json'
      : 'assets/animations/paint_ball.json';

  double get progress => timing.flight == Duration.zero
      ? 1
      : (elapsed.inMicroseconds / timing.flight.inMicroseconds)
            .clamp(0.0, 1.0)
            .toDouble();

  bool get inImpact => elapsed >= timing.flight;
  ScoringMotionSample get sample =>
      event.path.sample(travelEnabled ? progress : 1);
}

typedef ScoringMotionCallback = void Function(ScoringMotionEvent event);
typedef ScoringMotionAssetBuilder =
    Widget Function(
      BuildContext context,
      ScoringActiveMotion active,
      Color teamColor,
    );

class ScoringMotionCoordinator extends ChangeNotifier {
  ScoringMotionCoordinator({
    this.motionTheme = const HoopitoMotionTheme.light(),
    this.mode = ScoringMotionMode.standard,
    this.onComplete,
    this.onImpact,
    this.onFallback,
  });

  final HoopitoMotionTheme motionTheme;
  final ScoringMotionMode mode;
  final ScoringMotionCallback? onComplete;
  final ScoringMotionCallback? onImpact;
  final ScoringMotionCallback? onFallback;
  final List<ScoringMotionEvent> _queue = <ScoringMotionEvent>[];
  final Set<String> _seenEventIds = <String>{};
  ScoringActiveMotion? _active;
  bool _disposed = false;
  bool _completionDispatching = false;

  ScoringActiveMotion? get active => _active;
  List<ScoringMotionEvent> get queuedEvents => List.unmodifiable(_queue);
  int get pendingCount => (_active == null ? 0 : 1) + _queue.length;

  bool submit(ScoringMotionEvent event) {
    if (_disposed) return false;
    if (!_seenEventIds.add(event.id)) return false;
    if (mode == ScoringMotionMode.disabled) {
      _finishImmediately(event, fallback: false);
      return true;
    }
    if (!event.geometryAvailable) {
      _finishImmediately(event, fallback: true);
      return true;
    }
    if (mode == ScoringMotionMode.reduced) {
      final timing = ScoringMotionTiming(
        flight: motionTheme.reducedReveal,
        impact: Duration.zero,
      );
      if (_active == null && !_completionDispatching) {
        _active = ScoringActiveMotion(event: event, mode: mode, timing: timing);
      } else {
        _queue.add(event);
        _timings[event.id] = timing;
      }
      notifyListeners();
      return true;
    }
    if (!event.assetAvailable) {
      _finishImmediately(event, fallback: true);
      return true;
    }
    final accelerate = pendingCount + 1 > 3;
    final timing = _timing(accelerated: accelerate);
    // Once the visual backlog crosses four, all already-queued (not the
    // currently flying) items use the same accelerated policy. This makes the
    // policy deterministic and guarantees a five-shot burst drains promptly.
    if (accelerate) {
      for (final queued in _queue) {
        _timings[queued.id] = _timing(accelerated: true);
      }
    }
    if (_active == null && !_completionDispatching) {
      _active = ScoringActiveMotion(event: event, timing: timing);
    } else {
      _queue.add(event);
      _timings[event.id] = timing;
    }
    notifyListeners();
    return true;
  }

  void _finishImmediately(ScoringMotionEvent event, {required bool fallback}) {
    try {
      if (fallback) {
        _dispatchFallback(event);
      } else {
        _dispatchComplete(event);
      }
    } catch (error, stack) {
      _recoverAfterDispatch();
      Error.throwWithStackTrace(error, stack);
    }
    _recoverAfterDispatch();
  }

  void _recoverAfterDispatch() {
    if (_disposed) return;
    if (_active == null) _startNext();
    if (!_disposed) notifyListeners();
  }

  void _dispatchComplete(ScoringMotionEvent event) {
    _completionDispatching = true;
    try {
      if (!_disposed) onComplete?.call(event);
    } finally {
      _completionDispatching = false;
    }
  }

  /*
   * Presentation failure is distinct from system-disabled motion: the former
   * tells the integration that it should use its explicit reveal fallback.
   */
  void _dispatchFallback(ScoringMotionEvent event) {
    _completionDispatching = true;
    try {
      if (_disposed) return;
      onFallback?.call(event);
      if (_disposed) return;
      onComplete?.call(event);
    } finally {
      _completionDispatching = false;
    }
  }

  final Map<String, ScoringMotionTiming> _timings = {};

  ScoringMotionTiming _timing({required bool accelerated}) =>
      ScoringMotionTiming(
        flight: accelerated
            ? motionTheme.acceleratedScoreFlight
            : motionTheme.scoreFlight,
        impact: accelerated
            ? motionTheme.acceleratedImpact
            : motionTheme.impact,
      );

  void advance(Duration elapsed) {
    if (_disposed || elapsed <= Duration.zero) return;
    var remaining = elapsed;
    while (!_disposed && _active != null && remaining > Duration.zero) {
      final current = _active!;
      if (!current.impactDispatched &&
          current.timing.flight <= current.elapsed + remaining) {
        remaining -= current.timing.flight - current.elapsed;
        current.elapsed = current.timing.flight;
        current.impactDispatched = true;
        _dispatchImpact(current.event);
        if (_disposed) return;
        final impactLeft = current.timing.total - current.elapsed;
        if (remaining < impactLeft) {
          current.elapsed += remaining;
          remaining = Duration.zero;
          continue;
        }
        remaining -= impactLeft;
        current.elapsed = current.timing.total;
      }
      final left = current.timing.total - current.elapsed;
      if (remaining < left) {
        current.elapsed += remaining;
        remaining = Duration.zero;
      } else {
        remaining -= left;
        final finished = current.event;
        _active = null;
        _completionDispatching = true;
        try {
          if (!_disposed) onComplete?.call(finished);
        } catch (error, stack) {
          _completionDispatching = false;
          _recoverAfterDispatch();
          Error.throwWithStackTrace(error, stack);
        } finally {
          _completionDispatching = false;
        }
        if (_disposed) return;
        // Completion callbacks may submit more work. Submit queues reentrant
        // events, keeping the already-queued FIFO entries in front.
        if (_active == null) _startNext();
      }
    }
    if (!_disposed) notifyListeners();
  }

  void _dispatchImpact(ScoringMotionEvent event) {
    _completionDispatching = true;
    try {
      if (!_disposed) onImpact?.call(event);
    } catch (error, stack) {
      _completionDispatching = false;
      _recoverAfterDispatch();
      Error.throwWithStackTrace(error, stack);
    } finally {
      _completionDispatching = false;
    }
  }

  bool cancelByEventId(String eventId) => _cancel(eventId, byLocation: false);

  bool cancelByLocationId(String locationId) =>
      _cancel(locationId, byLocation: true);

  /// Completes a motion after a runtime asset/geometry failure. This is also
  /// useful to an overlay's asset errorBuilder: the score has already been
  /// committed, so presentation can reveal immediately and drain the queue.
  bool fail(String eventId) {
    if (_disposed) return false;
    if (_active?.event.id == eventId) {
      final failed = _active!.event;
      _active = null;
      try {
        _dispatchFallback(failed);
      } catch (error, stack) {
        _recoverAfterDispatch();
        Error.throwWithStackTrace(error, stack);
      }
      _recoverAfterDispatch();
      return true;
    }
    final index = _queue.indexWhere((event) => event.id == eventId);
    if (index < 0) return false;
    final failed = _queue.removeAt(index);
    _timings.remove(failed.id);
    try {
      _dispatchFallback(failed);
    } catch (error, stack) {
      _recoverAfterDispatch();
      Error.throwWithStackTrace(error, stack);
    }
    _recoverAfterDispatch();
    return true;
  }

  bool _cancel(String identifier, {required bool byLocation}) {
    if (_disposed) return false;
    if (_active != null &&
        (byLocation ? _active!.event.locationId : _active!.event.id) ==
            identifier) {
      _active = null;
      _startNext();
      notifyListeners();
      return true;
    }
    final removed = _queue
        .where(
          (event) => (byLocation ? event.locationId : event.id) == identifier,
        )
        .toList();
    final before = _queue.length;
    _queue.removeWhere(
      (event) => (byLocation ? event.locationId : event.id) == identifier,
    );
    if (_queue.length != before) {
      for (final event in removed) {
        _timings.remove(event.id);
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  void _startNext() {
    if (_queue.isEmpty || _disposed) return;
    final event = _queue.removeAt(0);
    final timing =
        _timings.remove(event.id) ??
        ScoringMotionTiming(
          flight: motionTheme.scoreFlight,
          impact: motionTheme.impact,
        );
    _active = ScoringActiveMotion(event: event, mode: mode, timing: timing);
  }

  @override
  void dispose() {
    _disposed = true;
    _active = null;
    _queue.clear();
    _timings.clear();
    _seenEventIds.clear();
    super.dispose();
  }
}

class ScoringMotionOverlay extends StatelessWidget {
  const ScoringMotionOverlay({
    required this.coordinator,
    this.assetBuilder,
    super.key,
  });

  final ScoringMotionCoordinator coordinator;
  final ScoringMotionAssetBuilder? assetBuilder;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: coordinator,
        builder: (context, child) {
          final active = coordinator.active;
          final color = active == null
              ? Colors.transparent
              : teamColorForScheme(
                  active.event.receipt.side,
                  Theme.of(context).colorScheme,
                );
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: ScoringMotionPainter(coordinator, ballColor: color),
              ),
              if (active != null && active.travelEnabled)
                _assetWidget(context, active, color),
            ],
          );
        },
      ),
    );
  }

  Widget _assetWidget(
    BuildContext context,
    ScoringActiveMotion active,
    Color color,
  ) {
    if (assetBuilder != null) return assetBuilder!(context, active, color);
    return Positioned(
      left: active.sample.position.dx - (active.inImpact ? 28 : 18),
      top: active.sample.position.dy - (active.inImpact ? 28 : 18),
      width: active.inImpact ? 56 : 36,
      height: active.inImpact ? 56 : 36,
      child: ScoringMotionLottieAsset(
        key: ValueKey('${active.event.id}-${active.assetName}'),
        coordinator: coordinator,
        active: active,
        teamColor: color,
      ),
    );
  }
}

/// Drives one offline Lottie composition from the coordinator's current phase.
/// The composition's source duration is intentionally ignored: every phase is
/// played from 0 to 1 across the scoring motion token, so impact cannot outlive
/// the durable reveal window.
class ScoringMotionLottieAsset extends StatefulWidget {
  const ScoringMotionLottieAsset({
    required this.coordinator,
    required this.active,
    required this.teamColor,
    super.key,
  });

  final ScoringMotionCoordinator coordinator;
  final ScoringActiveMotion active;
  final Color teamColor;

  @override
  ScoringMotionLottieAssetState createState() =>
      ScoringMotionLottieAssetState();
}

class ScoringMotionLottieAssetState extends State<ScoringMotionLottieAsset>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Duration? animationDuration;

  AnimationController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1),
    );
  }

  void _onLoaded(LottieComposition composition) {
    if (!mounted) return;
    final duration = widget.active.inImpact
        ? widget.active.timing.impact
        : widget.active.timing.flight;
    _controller.duration = duration;
    animationDuration = duration;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      widget.active.assetName,
      animate: false,
      repeat: false,
      controller: _controller,
      delegates: LottieDelegates(
        values: [
          ValueDelegate.color([
            '**',
            'teamFill',
            'teamFill',
            'teamFill',
          ], value: widget.teamColor),
        ],
      ),
      onLoaded: _onLoaded,
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.coordinator.fail(widget.active.event.id);
        });
        return const SizedBox.shrink();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class ScoringMotionPainter extends CustomPainter {
  ScoringMotionPainter(this.coordinator, {this.ballColor = Colors.white})
    : super(repaint: coordinator);

  final ScoringMotionCoordinator coordinator;
  final Color ballColor;

  @override
  void paint(Canvas canvas, Size size) {
    final active = coordinator.active;
    if (active == null) return;
    if (!active.travelEnabled) {
      canvas.drawCircle(
        active.event.destination,
        10,
        Paint()
          ..color = ballColor.withValues(alpha: active.colorRevealProgress),
      );
      return;
    }
    final sample = active.sample;
    final paint = Paint()..color = ballColor;
    if (active.trailEnabled) {
      for (final node in sample.trail) {
        canvas.drawCircle(
          node.position,
          3.5,
          paint..color = ballColor.withValues(alpha: node.opacity),
        );
      }
    }
    if (active.inImpact) {
      // The compact splash composition is the sole impact spread owner.
      return;
    }
    canvas.drawCircle(sample.position, 7, paint..color = ballColor);
  }

  @override
  bool shouldRepaint(covariant ScoringMotionPainter oldDelegate) =>
      oldDelegate.coordinator != coordinator;
}
