import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/design_system/recording_confirmation.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/rules/rule_engine.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';
import 'package:hoopito/features/scoring/widgets/court_painter.dart';
import 'package:hoopito/features/scoring/widgets/score_side_panel.dart';
import 'package:hoopito/features/scoring/widgets/scoring_guide.dart';
import 'package:hoopito/features/scoring/motion/scoring_motion.dart';

const scoringResumeClockKey = Key('scoring-resume-clock');

double _landscapeSideWidth(double availableWidth) =>
    (availableWidth * 0.17).clamp(112.0, 188.0);

bool _usesPortraitScoringLayout(BoxConstraints constraints) =>
    constraints.maxWidth < 600 &&
    constraints.maxHeight > constraints.maxWidth * 1.05;

class ScoringPage extends StatefulWidget {
  const ScoringPage({
    this.matchId,
    this.setup,
    this.controller,
    this.onOpenReplay,
    this.onRequestLeave,
    this.onResumeClock,
    this.onPauseMatch,
    this.onResumePausedMatch,
    this.onReturnHomePaused,
    this.onContinueDecision,
    this.onFinishDecision,
    this.onFinishWithCoverage,
    this.showInitialGuide = false,
    this.onGuideDismissed,
    this.clockNowUtc,
    this.clockTick = const Duration(seconds: 1),
    this.onActionCommitted,
    this.motionPreferenceLoader,
    this.motionPreferenceListenable,
    this.motionPreference,
    super.key,
  }) : assert(matchId != null || setup != null || controller != null);

  final String? matchId;
  final bool showInitialGuide;
  final VoidCallback? onGuideDismissed;
  final MatchSetup? setup;
  final ScoringController? controller;
  final VoidCallback? onOpenReplay;
  final Future<void> Function()? onRequestLeave;
  final VoidCallback? onResumeClock;
  final Future<void> Function()? onPauseMatch;
  final Future<void> Function()? onResumePausedMatch;
  final Future<void> Function()? onReturnHomePaused;
  final Future<void> Function()? onContinueDecision;
  final Future<void> Function(int redScore, int blueScore)? onFinishDecision;
  final Future<void> Function(
    int redScore,
    int blueScore,
    TrackingCoverage coverage,
  )?
  onFinishWithCoverage;
  final DateTime Function()? clockNowUtc;
  final Duration clockTick;
  final FutureOr<void> Function()? onActionCommitted;

  /// Read-only route seam for the persisted scoring feedback preference.
  /// Settings owns writes; scoring only consumes the value.
  final Future<MotionPreference> Function()? motionPreferenceLoader;
  final ValueListenable<MotionPreference>? motionPreferenceListenable;
  final MotionPreference? motionPreference;

  @override
  State<ScoringPage> createState() => _ScoringPageState();
}

class _ScoringPageState extends State<ScoringPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool get _canFinish =>
      widget.onFinishDecision != null || widget.onFinishWithCoverage != null;
  late ScoringController _controller;
  bool _ownsController = false;
  bool _guideVisible = false;
  bool _leaveBusy = false;
  bool _decisionBusy = false;
  bool _interactionPaused = false;
  bool _pauseTransitionBusy = false;
  bool _pausedPanelVisible = false;
  DialogRoute<void>? _pausedPanelRoute;
  bool _pausedPanelScheduled = false;
  Timer? _clockTicker;
  Timer? _supplementTicker;
  final GlobalKey _motionWorkspaceKey = GlobalKey();
  final GlobalKey _courtGeometryKey = GlobalKey();
  late final Map<TeamSide, Map<int, GlobalKey>> _scoreButtonKeys = {
    TeamSide.blue: {
      for (final points in [1, 2, 3]) points: GlobalKey(),
    },
    TeamSide.red: {
      for (final points in [1, 2, 3]) points: GlobalKey(),
    },
  };
  late final Map<TeamSide, GlobalKey> _missButtonKeys = {
    TeamSide.blue: GlobalKey(),
    TeamSide.red: GlobalKey(),
  };
  late ScoringMotionCoordinator _motionCoordinator;
  Ticker? _motionTicker;
  Duration _motionElapsed = Duration.zero;
  late MotionPreference _motionPreference =
      widget.motionPreference ?? MotionPreference.standard;
  ScoringMotionMode _motionMode = ScoringMotionMode.standard;
  final Set<String> _hiddenShotLocationIds = <String>{};
  final Set<String> _submittedMotionEventIds = <String>{};
  final Map<String, TransientShotMarker> _transientMarkers =
      <String, TransientShotMarker>{};
  final Map<String, EraserShotMarker> _eraserMarkers =
      <String, EraserShotMarker>{};
  final Map<String, AnimationController> _eraserControllers =
      <String, AnimationController>{};
  Timer? _foulStampTimer;
  TeamSide? _foulStampSide;
  int _foulStampVersion = 0;
  bool _showBlueMissLocations = true;
  bool _showRedMissLocations = true;
  bool _disposed = false;
  int _actionGeneration = 0;
  ValueListenable<MotionPreference>? _attachedMotionPreference;

  @override
  void initState() {
    super.initState();
    _guideVisible = widget.showInitialGuide;
    WidgetsBinding.instance.addObserver(this);
    _attachController();
    _interactionPaused =
        _restoresPersistedPause && _controller.state.isManuallyPaused;
    _schedulePersistedPausePanel();
    _motionCoordinator = _createMotionCoordinator();
    _startTickers();
    _attachMotionPreferenceListenable();
    final loader = widget.motionPreferenceLoader;
    if (loader != null) {
      unawaited(
        loader().then<void>((preference) {
          if (!mounted || _disposed) return;
          _motionPreference = preference;
          _updateMotionMode();
          setState(() {});
        }, onError: (Object error, StackTrace stack) {}),
      );
    }
  }

  @override
  void didUpdateWidget(covariant ScoringPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showInitialGuide && widget.showInitialGuide) {
      _guideVisible = true;
    }
    final controllerChanged =
        oldWidget.controller != widget.controller ||
        oldWidget.matchId != widget.matchId ||
        oldWidget.setup != widget.setup;
    if (controllerChanged) {
      _actionGeneration++;
      _cancelAllMotions();
      _detachController();
      _attachController();
      _showBlueMissLocations = true;
      _showRedMissLocations = true;
      _interactionPaused =
          _restoresPersistedPause && _controller.state.isManuallyPaused;
      _schedulePersistedPausePanel();
    }
    if (controllerChanged ||
        oldWidget.clockNowUtc != widget.clockNowUtc ||
        oldWidget.clockTick != widget.clockTick) {
      _startTickers();
    }
    _attachMotionPreferenceListenable();
    if (oldWidget.motionPreferenceListenable !=
        widget.motionPreferenceListenable) {
      _updateMotionMode();
    }
    if (oldWidget.motionPreference != widget.motionPreference &&
        widget.motionPreference != null) {
      _motionPreference = widget.motionPreference!;
      _updateMotionMode();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final pausedRoute = _pausedPanelRoute;
    final pausedNavigator = pausedRoute?.navigator;
    if (pausedRoute != null && pausedNavigator != null) {
      // A dialog belongs to the Navigator, so disposing its scoring page
      // does not remove it. Remove only this owned route after navigation
      // has finished updating the page stack.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (pausedNavigator.mounted && pausedRoute.isActive) {
          pausedNavigator.removeRoute(pausedRoute);
        }
      });
    }
    WidgetsBinding.instance.removeObserver(this);
    _detachMotionPreferenceListenable();
    _cancelAllMotions();
    _motionCoordinator.dispose();
    _motionTicker?.dispose();
    _disposeErasers();
    _foulStampTimer?.cancel();
    _clockTicker?.cancel();
    _supplementTicker?.cancel();
    _detachController();
    super.dispose();
  }

  void _attachController() {
    _controller =
        widget.controller ??
        ScoringController(matchId: widget.matchId, setup: widget.setup);
    _ownsController = widget.controller == null;
    _controller.addListener(_handleStateChanged);
  }

  void _detachController() {
    _controller.removeListener(_handleStateChanged);
    if (_ownsController) _controller.dispose();
  }

  void _attachMotionPreferenceListenable() {
    final next = widget.motionPreferenceListenable;
    if (identical(next, _attachedMotionPreference)) return;
    _attachedMotionPreference?.removeListener(_handleMotionPreferenceChanged);
    _attachedMotionPreference = next;
    next?.addListener(_handleMotionPreferenceChanged);
    if (next != null) {
      _motionPreference = next.value;
    }
  }

  void _detachMotionPreferenceListenable() {
    _attachedMotionPreference?.removeListener(_handleMotionPreferenceChanged);
    _attachedMotionPreference = null;
  }

  void _handleMotionPreferenceChanged() {
    if (!mounted || _disposed) return;
    final listenable = _attachedMotionPreference;
    if (listenable == null || _motionPreference == listenable.value) return;
    _motionPreference = listenable.value;
    _updateMotionMode();
    if (mounted && !_disposed) setState(() {});
  }

  ScoringMotionCoordinator _createMotionCoordinator() {
    return ScoringMotionCoordinator(
      mode: _motionMode,
      onImpact: _revealMotion,
      onComplete: _completeMotion,
      onFallback: _reconcileMotion,
    )..addListener(_handleMotionChanged);
  }

  void _handleMotionChanged() {
    if (_motionCoordinator.active != null) {
      _motionTicker ??= createTicker(_advanceMotion);
      if (!_motionTicker!.isActive) {
        _motionElapsed = Duration.zero;
        _motionTicker!.start();
      }
    } else {
      _motionTicker?.stop();
      _motionElapsed = Duration.zero;
    }
    if (mounted && !_disposed) setState(() {});
  }

  void _advanceMotion(Duration elapsed) {
    if (_disposed) return;
    final delta = elapsed - _motionElapsed;
    _motionElapsed = elapsed;
    if (delta > Duration.zero) _motionCoordinator.advance(delta);
  }

  void _updateMotionMode() {
    if (!mounted) return;
    final media = MediaQuery.maybeOf(context);
    final next = media?.disableAnimations == true
        ? ScoringMotionMode.disabled
        : (media?.accessibleNavigation == true ||
              _motionPreference == MotionPreference.reduced)
        ? ScoringMotionMode.reduced
        : ScoringMotionMode.standard;
    if (next == _motionMode) return;
    // A visual preference change must not discard a pending match command or
    // its confirmation. Controller/lifecycle changes still invalidate actions.
    _cancelAllMotions(invalidateActions: false);
    _motionCoordinator.removeListener(_handleMotionChanged);
    _motionCoordinator.dispose();
    _motionMode = next;
    _motionCoordinator = _createMotionCoordinator();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotionMode();
  }

  @override
  void didChangeMetrics() => _cancelAllMotions();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancelAllMotions();
  }

  void _cancelAllMotions({bool invalidateActions = true}) {
    if (invalidateActions) _actionGeneration++;
    _motionTicker?.stop();
    _motionElapsed = Duration.zero;
    for (final event in [
      if (_motionCoordinator.active != null) _motionCoordinator.active!.event,
      ..._motionCoordinator.queuedEvents,
    ]) {
      _motionCoordinator.cancelByEventId(event.id);
    }
    _hiddenShotLocationIds.clear();
    _submittedMotionEventIds.clear();
    _transientMarkers.clear();
    _foulStampTimer?.cancel();
    _foulStampTimer = null;
    _foulStampSide = null;
    _disposeErasers();
    if (mounted && !_disposed) setState(() {});
  }

  void _disposeErasers() {
    for (final controller in _eraserControllers.values) {
      controller.dispose();
    }
    _eraserControllers.clear();
    _eraserMarkers.clear();
  }

  void _startEraser(ScoringShotLocation location, int generation) {
    if (!_isCurrentAction(generation, _controller)) return;
    if (_motionMode != ScoringMotionMode.standard) return;
    final id = location.id;
    _eraserControllers[id]?.dispose();
    final animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _eraserControllers[id] = animation;
    _eraserMarkers[id] = EraserShotMarker(
      id: id,
      point: location.point,
      side: location.side,
      progress: 0,
      isMiss: location.isMiss,
    );
    animation.addListener(() {
      if (!mounted || _disposed || !_eraserControllers.containsKey(id)) return;
      _eraserMarkers[id] = EraserShotMarker(
        id: id,
        point: location.point,
        side: location.side,
        progress: animation.value,
        isMiss: location.isMiss,
      );
      setState(() {});
    });
    animation.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted || _disposed) return;
      animation.dispose();
      _eraserControllers.remove(id);
      _eraserMarkers.remove(id);
      if (mounted && !_disposed) setState(() {});
    });
    if (mounted && !_disposed) setState(() {});
    animation.forward();
  }

  void _reconcileMotion(ScoringMotionEvent event) {
    _hiddenShotLocationIds.remove(event.locationId);
    _transientMarkers.remove(event.locationId);
    if (mounted && !_disposed) setState(() {});
  }

  void _revealMotion(ScoringMotionEvent event) {
    _hiddenShotLocationIds.remove(event.locationId);
    _transientMarkers.remove(event.locationId);
    if (mounted && !_disposed) setState(() {});
  }

  void _completeMotion(ScoringMotionEvent event) {
    _reconcileMotion(event);
  }

  void _startTickers() {
    _clockTicker?.cancel();
    if (widget.clockTick > Duration.zero && _controller.timerEnabled) {
      _clockTicker = Timer.periodic(widget.clockTick, (_) {
        if (mounted) setState(() {});
      });
    }
    _syncSupplementTicker();
  }

  void _syncSupplementTicker() {
    _supplementTicker?.cancel();
    _supplementTicker = null;
    final window = _controller.locationSupplementWindow;
    if (!mounted || _disposed || window == null) return;

    final now = _nowUtc();
    if (!now.isBefore(window.expiresAtUtc)) {
      _controller.expireSupplementWindow(atUtc: now);
      return;
    }

    final remainingMilliseconds = window.expiresAtUtc
        .difference(now)
        .inMilliseconds;
    final displayedSeconds = (remainingMilliseconds / 1000).ceil().clamp(1, 10);
    final nextDisplayBoundaryMilliseconds =
        remainingMilliseconds - (displayedSeconds - 1) * 1000;
    _supplementTicker = Timer(
      Duration(milliseconds: nextDisplayBoundaryMilliseconds.clamp(1, 1000)),
      () {
        _supplementTicker = null;
        if (!mounted || _disposed) return;
        final expired = _controller.expireSupplementWindow(atUtc: _nowUtc());
        if (!expired && mounted) setState(() {});
        _syncSupplementTicker();
      },
    );
  }

  DateTime _nowUtc() => (widget.clockNowUtc?.call() ?? DateTime.now()).toUtc();

  ClockProjection? _displayClock() {
    final persisted = _controller.clock;
    if (!_controller.timerEnabled || persisted == null) return null;
    return ClockEngine().project(
      // A running projection already includes elapsed time in normalizedState
      // while retaining its original anchor. Re-project the stored state so
      // that interval is counted once; preserve terminal recovery/expiry.
      state: persisted.requiresPersistence
          ? persisted.normalizedState
          : persisted.state,
      now: _nowUtc(),
    );
  }

  void _handleStateChanged() {
    final durableIds = _controller.state.shotLocations
        .map((location) => location.id)
        .toSet();
    final stale = <String>{
      ..._hiddenShotLocationIds,
      ..._transientMarkers.keys,
    }.where((id) => !durableIds.contains(id)).toList();
    for (final id in stale) {
      _motionCoordinator.cancelByLocationId(id);
      _hiddenShotLocationIds.remove(id);
      _transientMarkers.remove(id);
    }
    _syncSupplementTicker();
    if (_restoresPersistedPause &&
        _controller.state.isManuallyPaused &&
        !_interactionPaused) {
      _interactionPaused = true;
      _schedulePersistedPausePanel();
    }
    if (mounted && !_disposed) setState(() {});
  }

  bool get _restoresPersistedPause =>
      widget.onResumePausedMatch != null || widget.onReturnHomePaused != null;

  void _schedulePersistedPausePanel() {
    if (!_interactionPaused ||
        _leaveBusy ||
        _pausedPanelVisible ||
        _pausedPanelScheduled ||
        _disposed) {
      return;
    }
    _pausedPanelScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pausedPanelScheduled = false;
      if (!mounted ||
          _disposed ||
          _leaveBusy ||
          !_interactionPaused ||
          _pausedPanelVisible ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      unawaited(_showPausedPanel());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final decisionControlsDeferred = _decisionControlsDeferred(state);
    final clock = _displayClock();
    final labels = _labels(context);
    final page = Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final portrait = _usesPortraitScoringLayout(constraints);
            return Stack(
              key: _motionWorkspaceKey,
              fit: StackFit.expand,
              children: [
                AbsorbPointer(
                  absorbing: _interactionPaused,
                  child: Column(
                    children: [
                      _Scoreboard(
                        state: state,
                        clock: clock,
                        portrait: portrait,
                        onLeave: _requestLeave,
                        onUndo: () => unawaited(_undoLastScoringAction()),
                        onFoul: (side) => unawaited(_recordFoul(side)),
                        foulEnabled:
                            !decisionControlsDeferred &&
                            state.courtFirstShotDraft == null &&
                            state.pendingLocation == null,
                        onMore: _showMore,
                        onFinish: decisionControlsDeferred
                            ? null
                            : _showMatchControls,
                        labels: labels,
                      ),
                      _buildRecordStatus(context, state),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildWorkspace(context, state, portrait: portrait),
                            if (_guideVisible)
                              Positioned(
                                left: portrait
                                    ? 16
                                    : _landscapeSideWidth(
                                            constraints.maxWidth,
                                          ) +
                                          12,
                                right: portrait
                                    ? 16
                                    : _landscapeSideWidth(
                                            constraints.maxWidth,
                                          ) +
                                          12,
                                top: 8,
                                bottom: 8,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  heightFactor: 1,
                                  child: ScoringGuide(
                                    onDismiss: () {
                                      setState(() => _guideVisible = false);
                                      widget.onGuideDismissed?.call();
                                    },
                                  ),
                                ),
                              ),
                            if (state.decision != null &&
                                !decisionControlsDeferred)
                              _buildDecisionOverlay(context, state),
                          ],
                        ),
                      ),
                      if (state.ruleHints.isNotEmpty ||
                          state.ruleWarnings.isNotEmpty)
                        _buildRuleHints(context, state),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ScoringMotionOverlay(
                      coordinator: _motionCoordinator,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (widget.onRequestLeave == null) return page;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_interactionPaused && !_pauseTransitionBusy) {
          unawaited(_requestLeave());
        }
      },
      child: page,
    );
  }

  Widget _buildWorkspace(
    BuildContext context,
    MatchScoringState state, {
    required bool portrait,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (portrait) {
          final sideHeight = constraints.maxHeight.clamp(0.0, 310.0);
          return Column(
            children: [
              Expanded(child: _buildCourt(context, state)),
              SizedBox(
                height: sideHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSidePanel(context, state, TeamSide.blue),
                    ),
                    Expanded(
                      child: _buildSidePanel(context, state, TeamSide.red),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        final sideWidth = _landscapeSideWidth(constraints.maxWidth);
        return Row(
          children: [
            SizedBox(
              width: sideWidth,
              child: _buildSidePanel(context, state, TeamSide.blue),
            ),
            Expanded(child: _buildCourt(context, state)),
            SizedBox(
              width: sideWidth,
              child: _buildSidePanel(context, state, TeamSide.red),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCourt(BuildContext context, MatchScoringState state) {
    final window = state.locationSupplementWindow;
    final remaining = _remainingSeconds(window);
    final prompt = state.courtFirstShotDraft != null
        ? _labels(context).chooseScoringSide
        : window == null
        ? null
        : window.points == 0
        ? _labels(context).missSupplementPrompt(
            _localizedSide(_localizations(context), window.side),
            remaining,
          )
        : _labels(context).supplementPrompt(
            _localizedSide(_localizations(context), window.side),
            window.points,
            remaining,
          );
    final displayHiddenIds = <String>{
      ..._hiddenShotLocationIds,
      for (final location in state.shotLocations)
        if (location.isMiss && !_showsMissLocations(location.side)) location.id,
    };
    return Padding(
      padding: const EdgeInsets.all(8),
      child: CourtView(
        key: const Key('scoring-court'),
        geometryKey: _courtGeometryKey,
        shotLocations: state.shotLocations,
        pendingLocation: state.pendingLocation,
        detailedShotDraft: state.courtFirstShotDraft,
        hiddenShotLocationIds: displayHiddenIds,
        transientMarkers: _transientMarkers.values
            .where(
              (marker) => !marker.isMiss || _showsMissLocations(marker.side),
            )
            .toList(growable: false),
        eraserMarkers: _eraserMarkers.values
            .where(
              (marker) => !marker.isMiss || _showsMissLocations(marker.side),
            )
            .toList(growable: false),
        locationPrompt: prompt,
        onPendingLocationChanged: _controller.updatePendingLocation,
        onCourtPointTap: _handleCourtPoint,
      ),
    );
  }

  int _remainingSeconds(LocationSupplementWindow? window) {
    if (window == null) return 0;
    final remaining = window.expiresAtUtc.difference(_nowUtc()).inMilliseconds;
    return (remaining / 1000).ceil().clamp(0, 10);
  }

  bool _showsMissLocations(TeamSide side) =>
      side == TeamSide.blue ? _showBlueMissLocations : _showRedMissLocations;

  void _setMissLocationsVisible(TeamSide side, bool visible) {
    if (_showsMissLocations(side) == visible) return;
    if (!visible) {
      final motions =
          <ScoringMotionEvent>[
            if (_motionCoordinator.active != null)
              _motionCoordinator.active!.event,
            ..._motionCoordinator.queuedEvents,
          ].where(
            (event) => event.receipt.points == 0 && event.receipt.side == side,
          );
      for (final event in motions.toList(growable: false)) {
        _motionCoordinator.cancelByEventId(event.id);
        _hiddenShotLocationIds.remove(event.locationId);
        _transientMarkers.remove(event.locationId);
      }
      final eraserIds = _eraserMarkers.entries
          .where((entry) => entry.value.isMiss && entry.value.side == side)
          .map((entry) => entry.key)
          .toList(growable: false);
      for (final id in eraserIds) {
        _eraserControllers.remove(id)?.dispose();
        _eraserMarkers.remove(id);
      }
    }
    setState(() {
      if (side == TeamSide.blue) {
        _showBlueMissLocations = visible;
      } else {
        _showRedMissLocations = visible;
      }
    });
  }

  Widget _buildSidePanel(
    BuildContext context,
    MatchScoringState state,
    TeamSide side,
  ) {
    final isBlue = side == TeamSide.blue;
    final window = state.locationSupplementWindow;
    final remaining = _remainingSeconds(window);
    final activeLocation = window != null && window.side == side;
    final reduceMotion =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        (MediaQuery.maybeAccessibleNavigationOf(context) ?? false) ||
        _motionMode != ScoringMotionMode.standard;
    final motion = Theme.of(context).extension<HoopitoMotionTheme>();
    final locationRevealDuration = switch (_motionMode) {
      ScoringMotionMode.disabled => Duration.zero,
      ScoringMotionMode.reduced =>
        motion?.reducedReveal ?? const Duration(milliseconds: 120),
      ScoringMotionMode.standard =>
        motion?.state ?? const Duration(milliseconds: 180),
    };
    final draft = state.courtFirstShotDraft;
    final decisionControlsDeferred = _decisionControlsDeferred(state);
    return ScoreSidePanel(
      key: Key('${side.name}-side-panel'),
      side: side,
      name: isBlue ? state.blueName : state.redName,
      teamLabel: _labels(context).sideName(side),
      score: isBlue ? state.score.blueScore : state.score.redScore,
      fouls: isBlue ? state.blueFouls : state.redFouls,
      scoreButtons: const [1, 2, 3],
      scoreEnabled:
          !decisionControlsDeferred &&
          (draft != null || state.pendingLocation == null),
      missEnabled:
          !decisionControlsDeferred &&
          (draft != null || state.pendingLocation == null),
      locationPoints: activeLocation ? window.points : null,
      locationRemainingSeconds: activeLocation ? remaining : null,
      locationRevealDuration: locationRevealDuration,
      reduceMotion: reduceMotion,
      scoreButtonKeys: _scoreButtonKeys[side],
      missButtonKey: _missButtonKeys[side],
      foulStamp: _foulStampSide == side,
      foulStampVersion: _foulStampVersion,
      onScore: (points) => unawaited(_recordScore(side, points)),
      onMiss: () => unawaited(_recordMiss(side)),
    );
  }

  Widget _buildRuleHints(BuildContext context, MatchScoringState state) {
    final l10n = _localizations(context);
    final messages = <String>[
      for (final hint in state.ruleHints) _localizedHint(l10n, hint),
      for (final warning in state.ruleWarnings)
        l10n.ruleFoulLimit(warning.limit, _localizedSide(l10n, warning.side)),
    ];
    return Container(
      key: const Key('scoring-rule-hints'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(messages.join(' · '), maxLines: 2)),
        ],
      ),
    );
  }

  Widget _buildDecisionOverlay(BuildContext context, MatchScoringState state) {
    final decision = state.decision!;
    final l10n = _localizations(context);
    final actions = <Widget>[
      if (decision.canContinue && widget.onContinueDecision != null)
        OutlinedButton(
          key: const Key('scoring-decision-continue'),
          onPressed: _decisionBusy ? null : _continueDecision,
          child: Text(l10n.continueMatch),
        ),
      if (decision.canFinish && _canFinish)
        FilledButton(
          key: const Key('scoring-decision-finish'),
          onPressed: _decisionBusy ? null : _confirmFinishDecision,
          child: Text(l10n.finishMatch),
        ),
    ];
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.28),
        child: Center(
          child: EditorialSheet(
            key: const Key('scoring-decision-dock'),
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  l10n.finalScoreLine(
                    state.blueName,
                    decision.blueScore,
                    state.redName,
                    decision.redScore,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCourtPoint(CourtPoint point) {
    final draft = _controller.courtFirstShotDraft;
    if (draft != null) {
      _controller.updateCourtFirstShot(point: point);
      return;
    }
    final window = _controller.locationSupplementWindow;
    if (window != null) {
      unawaited(_attachSupplement(point));
      return;
    }
    if (!_controller.beginOrMoveCourtFirstShot(point)) {
      _showActionRejected(_labels(context).actionRejected);
    }
  }

  Offset? _scoreButtonCenter(TeamSide side, int points) {
    final sourceKey = points == 0
        ? _missButtonKeys[side]
        : _scoreButtonKeys[side]?[points];
    final box = sourceKey?.currentContext?.findRenderObject();
    final overlay = _motionWorkspaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox || !box.hasSize) return null;
    final global = box.localToGlobal(box.size.center(Offset.zero));
    return overlay.globalToLocal(global);
  }

  ScoringMotionEvent _motionEvent(
    ShotLocationCommitReceipt receipt,
    Offset? source,
  ) {
    final overlay = _motionWorkspaceKey.currentContext?.findRenderObject();
    final court = _courtGeometryKey.currentContext?.findRenderObject();
    if (overlay is! RenderBox || court is! RenderBox || !court.hasSize) {
      return ScoringMotionEvent(
        receipt: receipt,
        sourceButton: source ?? Offset.zero,
        courtBounds: Rect.zero,
        safeWorkspace: Rect.zero,
        geometryAvailable: false,
      );
    }
    final courtRect = HalfCourtGeometry.courtRectForSize(court.size);
    final topLeft = overlay.globalToLocal(
      court.localToGlobal(courtRect.topLeft),
    );
    final bottomRight = overlay.globalToLocal(
      court.localToGlobal(courtRect.bottomRight),
    );
    final bounds = Rect.fromPoints(topLeft, bottomRight);
    return ScoringMotionEvent(
      receipt: receipt,
      sourceButton: source ?? Offset.zero,
      courtBounds: bounds,
      safeWorkspace: Offset.zero & overlay.size,
      geometryAvailable: source != null && !bounds.isEmpty,
    );
  }

  void _submitReceiptMotion(ShotLocationCommitReceipt receipt, Offset? source) {
    if (_disposed) return;
    if (receipt.points == 0 && !_showsMissLocations(receipt.side)) return;
    if (!_submittedMotionEventIds.add(receipt.eventId)) return;
    final marker = TransientShotMarker(
      id: receipt.shotLocationId,
      point: receipt.point,
      side: receipt.side,
      isMiss: receipt.points == 0,
    );
    _hiddenShotLocationIds.add(receipt.shotLocationId);
    _transientMarkers[receipt.shotLocationId] = marker;
    if (mounted && !_disposed) setState(() {});
    try {
      final event = _motionEvent(receipt, source);
      final accepted = _motionCoordinator.submit(event);
      if (!accepted) _reconcileMotion(event);
    } on Object {
      // Presentation failures must reveal the durable projection immediately.
      _reconcileMotion(
        ScoringMotionEvent(
          receipt: receipt,
          sourceButton: source ?? Offset.zero,
          courtBounds: Rect.zero,
          safeWorkspace: Rect.zero,
          geometryAvailable: false,
        ),
      );
    }
  }

  Future<void> _attachSupplement(CourtPoint point) async {
    final generation = _actionGeneration;
    final controller = _controller;
    try {
      final receipt = await controller.attachSupplementLocationWithReceipt(
        point,
      );
      if (!_isCurrentAction(generation, controller)) return;
      if (receipt != null) {
        final source = _scoreButtonCenter(receipt.side, receipt.points);
        _submitReceiptMotion(receipt, source);
        _notifyCommitted();
      } else if (mounted) {
        _showActionRejected(_labels(context).supplementExpired);
      }
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return;
      _showCommandFailure(failure);
    }
  }

  Future<void> _recordScore(TeamSide side, int points) async {
    final labels = _labels(context);
    final l10n = _localizations(context);
    final draft = _controller.courtFirstShotDraft;
    if (draft != null) {
      final generation = _actionGeneration;
      final controller = _controller;
      controller.updateCourtFirstShot(
        side: side,
        outcome: ShotOutcome.made,
        points: points,
      );
      try {
        final receipt = await controller.commitCourtFirstShotWithReceipt();
        if (!_isCurrentAction(generation, controller)) return;
        if (receipt != null) {
          final source = _scoreButtonCenter(receipt.side, receipt.points);
          _submitReceiptMotion(receipt, source);
          _notifyCommitted();
        } else {
          _showActionRejected(labels.actionRejected);
        }
      } on MatchCommandFailure catch (failure) {
        if (!_isCurrentAction(generation, controller)) return;
        _showCommandFailure(failure);
      }
      return;
    }
    final generation = _actionGeneration;
    final controller = _controller;
    try {
      final accepted = await controller.recordScoreCommitted(
        side: side,
        points: points,
      );
      if (!_isCurrentAction(generation, controller)) return;
      if (accepted) {
        _notifyCommitted();
      } else {
        _showActionRejected(l10n.scoringResolvePending);
      }
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return;
      _showCommandFailure(failure);
    }
  }

  bool _isCurrentAction(int generation, ScoringController controller) {
    return mounted &&
        !_disposed &&
        generation == _actionGeneration &&
        identical(controller, _controller);
  }

  Future<bool> _recordMiss(TeamSide side, {bool rethrowFailure = false}) async {
    final l10n = _localizations(context);
    final generation = _actionGeneration;
    final controller = _controller;
    final draft = _controller.courtFirstShotDraft;
    if (draft != null) {
      controller.updateCourtFirstShot(
        side: side,
        outcome: ShotOutcome.missed,
        points: 0,
      );
      try {
        final receipt = await controller.commitCourtFirstShotWithReceipt();
        if (!_isCurrentAction(generation, controller)) return false;
        if (receipt != null) {
          _submitReceiptMotion(
            receipt,
            _scoreButtonCenter(receipt.side, receipt.points),
          );
          _notifyCommitted();
          return true;
        }
        return false;
      } on MatchCommandFailure catch (failure) {
        if (!_isCurrentAction(generation, controller)) return false;
        if (rethrowFailure) throw _moreFailure(failure);
        _showCommandFailure(failure);
        return false;
      }
    }
    try {
      final accepted = await controller.recordMissCommitted(side: side);
      if (!_isCurrentAction(generation, controller)) return false;
      if (accepted) {
        _notifyCommitted();
      } else {
        _showActionRejected(l10n.scoringMissTrackingDisabled);
      }
      return accepted;
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return false;
      if (rethrowFailure) throw _moreFailure(failure);
      _showCommandFailure(failure);
      return false;
    }
  }

  Future<bool> _recordFreeThrow(
    TeamSide side,
    bool made, {
    bool rethrowFailure = false,
  }) async {
    final generation = _actionGeneration;
    final controller = _controller;
    try {
      final accepted = await controller.recordFreeThrowCommitted(
        side: side,
        made: made,
      );
      if (!_isCurrentAction(generation, controller)) return false;
      if (accepted) _notifyCommitted();
      return accepted;
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return false;
      if (rethrowFailure) throw _moreFailure(failure);
      _showCommandFailure(failure);
      return false;
    }
  }

  Future<bool> _recordPossession(
    TeamSide side, {
    bool rethrowFailure = false,
  }) async {
    final generation = _actionGeneration;
    final controller = _controller;
    try {
      final accepted = await controller.recordPossessionCommitted(side);
      if (!_isCurrentAction(generation, controller)) return false;
      if (accepted) _notifyCommitted();
      return accepted;
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return false;
      if (rethrowFailure) throw _moreFailure(failure);
      _showCommandFailure(failure);
      return false;
    }
  }

  Future<void> _recordFoul(TeamSide side) async {
    final labels = _labels(context);
    if (_controller.courtFirstShotDraft != null ||
        _controller.state.pendingLocation != null) {
      _showActionRejected(labels.actionRejected);
      return;
    }
    final generation = _actionGeneration;
    final controller = _controller;
    final foulStampDuration =
        Theme.of(context).extension<HoopitoMotionTheme>()?.foulStamp ??
        const Duration(milliseconds: 180);
    try {
      final accepted = await controller.recordFoulCommitted(side);
      if (!_isCurrentAction(generation, controller)) return;
      if (accepted) {
        _foulStampTimer?.cancel();
        _foulStampVersion++;
        if (mounted) setState(() => _foulStampSide = side);
        _foulStampTimer = Timer(foulStampDuration, () {
          if (mounted && !_disposed) setState(() => _foulStampSide = null);
        });
        _notifyCommitted();
      } else {
        _showActionRejected(labels.actionRejected);
      }
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return;
      _showCommandFailure(failure);
    }
  }

  Future<void> _undoLastScoringAction() async {
    final l10n = _localizations(context);
    final generation = _actionGeneration;
    final controller = _controller;
    // A court-first marker is still local state, so Undo first clears the
    // gray point without touching the durable scoring history. Legacy local
    // projections may expose the same marker as a pending supplement; clear
    // that draft before asking the controller for the durable undo.
    if (_controller.courtFirstShotDraft != null) {
      controller.cancelCourtFirstShot();
      return;
    }
    if (_controller.state.pendingLocation != null &&
        _controller.locationSupplementWindow != null) {
      controller.cancelLocateLastUnlocatedShot();
    }
    final before = List<ScoringShotLocation>.of(controller.state.shotLocations);
    try {
      final accepted = await controller.undoLastScoringActionCommitted();
      if (!_isCurrentAction(generation, controller)) return;
      if (accepted) {
        final afterIds = controller.state.shotLocations
            .map((item) => item.id)
            .toSet();
        for (final location in before.where(
          (item) => !afterIds.contains(item.id),
        )) {
          _motionCoordinator.cancelByLocationId(location.id);
          _startEraser(location, generation);
        }
        _notifyCommitted();
      } else {
        _showActionRejected(l10n.scoringUndoFailed);
      }
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return;
      _showCommandFailure(failure);
    }
  }

  Future<void> _requestLeave() async {
    final generation = _actionGeneration;
    final controller = _controller;
    final onRequestLeave = widget.onRequestLeave;
    if (onRequestLeave == null) {
      _cancelAllMotions();
      if (mounted) await Navigator.of(context).maybePop();
      return;
    }
    if (_leaveBusy) return;
    final state = controller.state;
    if (state.pendingLocation != null || state.courtFirstShotDraft != null) {
      final labels = _labels(context);
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(labels.pendingTitle),
          content: Text(labels.pendingBody),
          actions: [
            TextButton(
              key: const Key('leave-stay'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(labels.stay),
            ),
            FilledButton(
              key: const Key('leave-cancel-pending'),
              onPressed: () {
                final cancelled = state.pendingLocation != null
                    ? controller.cancelLocateLastUnlocatedShot()
                    : controller.cancelCourtFirstShot();
                if (cancelled && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(labels.cancelAndLeave),
            ),
          ],
        ),
      );
      if (leave != true || !_isCurrentAction(generation, controller)) return;
    }
    _cancelAllMotions();
    final leaveGeneration = _actionGeneration;
    final leaveController = _controller;
    _leaveBusy = true;
    try {
      await onRequestLeave();
    } finally {
      if (_isCurrentAction(leaveGeneration, leaveController)) {
        setState(() => _leaveBusy = false);
        if (_interactionPaused) _schedulePersistedPausePanel();
      }
    }
  }

  Future<void> _showMatchControls() async {
    if (_decisionBusy ||
        _interactionPaused ||
        _decisionControlsDeferred(_controller.state)) {
      return;
    }
    final labels = _labels(context);
    final action = await showDialog<_MatchControlAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope<void>(
        canPop: false,
        child: AlertDialog(
          key: const Key('scoring-match-controls'),
          title: Text(labels.matchControlsTitle),
          content: Text(labels.matchControlsBody),
          actions: [
            TextButton(
              key: const Key('match-controls-return'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_MatchControlAction.returnToScoring),
              child: Text(labels.returnToScoring),
            ),
            OutlinedButton(
              key: const Key('match-controls-pause'),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_MatchControlAction.pause),
              child: Text(labels.pauseMatch),
            ),
            FilledButton(
              key: const Key('match-controls-finish'),
              onPressed:
                  !_canFinish ||
                      _controller.state.decision?.canFinish == false ||
                      _decisionControlsDeferred(_controller.state)
                  ? null
                  : () => Navigator.of(
                      dialogContext,
                    ).pop(_MatchControlAction.finish),
              child: Text(labels.finish),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _MatchControlAction.pause:
        await _pauseFromMatchControls();
        return;
      case _MatchControlAction.finish:
        await _confirmFinishDecision();
        return;
      case _MatchControlAction.returnToScoring:
      case null:
        return;
    }
  }

  Widget _buildRecordStatus(BuildContext context, MatchScoringState state) {
    final l10n = _localizations(context);
    final saving = _controller.isSaving;
    final failed = _controller.hasSaveFailure;
    final event = state.events.where((event) => !event.isDeleted).lastOrNull;
    final action = event == null
        ? l10n.replayNoData
        : [
            if (event.side != null)
              event.side == TeamSide.red ? state.redName : state.blueName,
            switch (event.type) {
              EventKind.score || EventKind.fieldGoal || EventKind.freeThrow =>
                event.outcome == ShotOutcome.missed
                    ? l10n.replayFilterMissed
                    : '+${event.points}',
              EventKind.miss => l10n.replayFilterMissed,
              EventKind.foul => l10n.replayFilterFouls,
              _ => event.note ?? event.customLabel ?? l10n.replayFilterOther,
            },
          ].join(' ');
    final status = failed
        ? l10n.v2SaveFailed
        : saving
        ? l10n.v2Saving
        : l10n.v2Saved;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('scoring-record-status'),
        color: editorialThemeOf(context).surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          children: [
            Icon(
              failed
                  ? Icons.error_outline
                  : saving
                  ? Icons.sync
                  : Icons.check_circle_outline,
              size: 16,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '${l10n.v2LastAction}: $action',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pauseFromMatchControls() async {
    if (_interactionPaused || _pauseTransitionBusy) return;
    setState(() {
      _interactionPaused = true;
      _pauseTransitionBusy = true;
    });
    var accepted = true;
    var failurePresented = false;
    if (!_controller.isManuallyPaused) {
      try {
        final pause = widget.onPauseMatch;
        if (pause != null) {
          await pause();
          _notifyCommitted();
        } else {
          accepted = await _pause(
            onFailurePresented: () => failurePresented = true,
          );
        }
      } on Object {
        accepted = false;
      }
    }
    if (!mounted) return;
    if (!accepted) {
      setState(() {
        _interactionPaused = false;
        _pauseTransitionBusy = false;
      });
      if (!failurePresented) {
        _showActionRejected(_labels(context).failureRetry);
      }
      return;
    }
    setState(() => _pauseTransitionBusy = false);
    await _showPausedPanel();
  }

  Future<void> _showPausedPanel() async {
    if (_pausedPanelVisible || _leaveBusy) return;
    _pausedPanelVisible = true;
    try {
      if (!mounted || !_interactionPaused) return;
      final labels = _labels(context);
      String? inlineFailure;
      Future<bool> Function()? inlineRetry;
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void setTransitionBusy(bool busy) {
              if (mounted) setState(() => _pauseTransitionBusy = busy);
              if (dialogContext.mounted) setDialogState(() {});
            }

            Future<void> runResume() async {
              if (_pauseTransitionBusy) return;
              setTransitionBusy(true);
              var accepted = false;
              try {
                accepted =
                    await (inlineRetry?.call() ??
                        _resumeFromPausedPanel(rethrowFailure: true));
                if (!accepted && mounted && dialogContext.mounted) {
                  inlineFailure = labels.failureRetry;
                }
              } on _MoreActionFailure catch (failure) {
                if (mounted && dialogContext.mounted) {
                  inlineFailure = failure.message;
                  inlineRetry = failure.retry;
                }
              } finally {
                if (mounted && dialogContext.mounted) {
                  setTransitionBusy(false);
                }
              }
              if (!accepted || !mounted || !dialogContext.mounted) return;
              setState(() => _interactionPaused = false);
              Navigator.of(dialogContext).pop();
            }

            Future<void> runReturnHome() async {
              if (_pauseTransitionBusy) return;
              setTransitionBusy(true);
              await _returnHomeFromPausedPanel(dialogContext);
              if (mounted && dialogContext.mounted) setTransitionBusy(false);
            }

            Future<void> runFinish() async {
              if (_pauseTransitionBusy) return;
              setTransitionBusy(true);
              await _finishFromPausedPanel(dialogContext);
              if (mounted && dialogContext.mounted) setTransitionBusy(false);
            }

            return PopScope<void>(
              canPop: false,
              child: AlertDialog(
                key: const Key('scoring-paused-panel'),
                icon: const Icon(Icons.pause_circle_outline, size: 40),
                title: Text(labels.matchPausedTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labels.matchPausedBody),
                    if (inlineFailure != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          inlineFailure!,
                          key: const Key('paused-resume-failure'),
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    key: const Key('paused-return-home'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _pauseTransitionBusy
                        ? null
                        : () => unawaited(runReturnHome()),
                    child: Text(labels.returnHome),
                  ),
                  if (inlineFailure == null || inlineRetry != null)
                    FilledButton(
                      key: Key(
                        inlineFailure == null
                            ? 'paused-continue'
                            : 'paused-retry',
                      ),
                      onPressed: _pauseTransitionBusy
                          ? null
                          : () => unawaited(runResume()),
                      child: Text(
                        inlineFailure == null
                            ? labels.continueMatch
                            : labels.retry,
                      ),
                    ),
                  OutlinedButton(
                    key: const Key('paused-finish'),
                    onPressed:
                        _pauseTransitionBusy ||
                            !_canFinish ||
                            _controller.state.decision?.canFinish == false
                        ? null
                        : () => unawaited(runFinish()),
                    child: Text(labels.finish),
                  ),
                ],
              ),
            );
          },
        ),
      );
      _pausedPanelRoute = route;
      await Navigator.of(context).push<void>(route);
    } finally {
      _pausedPanelRoute = null;
      _pausedPanelVisible = false;
      if (mounted && _interactionPaused) _schedulePersistedPausePanel();
    }
  }

  Future<void> _returnHomeFromPausedPanel(BuildContext dialogContext) async {
    if (!await _discardDraftBeforeLeaving() || !mounted) return;
    final goHome = widget.onReturnHomePaused ?? widget.onRequestLeave;
    if (goHome == null) {
      setState(() => _interactionPaused = false);
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      if (mounted) await Navigator.of(context).maybePop();
      return;
    }
    try {
      await goHome();
      if (!mounted) return;
      setState(() => _interactionPaused = false);
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    } on Object {
      if (mounted) _showActionRejected(_labels(context).failureRetry);
    }
  }

  Future<void> _finishFromPausedPanel(BuildContext dialogContext) async {
    final finished = await _confirmFinishDecision();
    if (!finished || !mounted) return;
    setState(() => _interactionPaused = false);
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
  }

  Future<bool> _resumeFromPausedPanel({bool rethrowFailure = false}) async {
    var accepted = true;
    if (_controller.isManuallyPaused || widget.onResumePausedMatch != null) {
      try {
        final resume = widget.onResumePausedMatch;
        if (resume != null) {
          await resume();
          _notifyCommitted();
        } else {
          accepted = await _resume(rethrowFailure: rethrowFailure);
        }
      } on _MoreActionFailure {
        rethrow;
      } on Object {
        accepted = false;
        if (!mounted) return false;
        if (rethrowFailure) {
          throw _MoreActionFailure(
            message: _labels(context).failureRetry,
            retry: () => _retryPausedCallback(widget.onResumePausedMatch),
          );
        }
        _showActionRejected(_labels(context).failureRetry);
      }
    }
    return mounted && accepted;
  }

  Future<bool> _retryPausedCallback(Future<void> Function()? resume) async {
    if (resume == null || !mounted) return false;
    try {
      await resume();
      if (!mounted) return false;
      _notifyCommitted();
      return true;
    } on Object {
      throw _MoreActionFailure(
        message: _labels(context).failureRetry,
        retry: () => _retryPausedCallback(resume),
      );
    }
  }

  Future<bool> _discardDraftBeforeLeaving() async {
    final state = _controller.state;
    if (state.pendingLocation == null && state.courtFirstShotDraft == null) {
      return true;
    }
    final labels = _labels(context);
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(labels.pendingTitle),
        content: Text(labels.pendingPauseExitBody),
        actions: [
          TextButton(
            key: const Key('paused-draft-stay'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(labels.stay),
          ),
          FilledButton(
            key: const Key('paused-draft-discard'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(labels.discardDraft),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return false;
    return state.pendingLocation != null
        ? _controller.cancelLocateLastUnlocatedShot()
        : _controller.cancelCourtFirstShot();
  }

  Future<void> _showMore() async {
    final labels = _labels(context);
    final clock = _displayClock();
    final workspace = _motionWorkspaceKey.currentContext?.findRenderObject();
    final compactHeight = workspace is RenderBox && workspace.size.height < 500;
    final sheetDuration =
        Theme.of(context).extension<HoopitoMotionTheme>()?.sheet ??
        Duration.zero;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      sheetAnimationStyle: AnimationStyle(
        duration: sheetDuration,
        reverseDuration: sheetDuration,
      ),
      builder: (sheetContext) {
        String? inlineFailure;
        Future<bool> Function()? inlineRetry;
        final ownerGeneration = _actionGeneration;
        final ownerController = _controller;

        return StatefulBuilder(
          builder: (sheetBuilderContext, setSheetState) {
            Future<bool> runMore(Future<bool> Function() action) async {
              if (!_isCurrentAction(ownerGeneration, ownerController) ||
                  !sheetBuilderContext.mounted) {
                return false;
              }
              try {
                final accepted = await action();
                if (!_isCurrentAction(ownerGeneration, ownerController) ||
                    !sheetBuilderContext.mounted) {
                  return false;
                }
                if (accepted) {
                  Navigator.of(sheetBuilderContext).pop();
                }
                return accepted;
              } on _MoreActionFailure catch (failure) {
                if (!_isCurrentAction(ownerGeneration, ownerController) ||
                    !sheetBuilderContext.mounted) {
                  return false;
                }
                setSheetState(() {
                  inlineFailure = failure.message;
                  inlineRetry = failure.retry;
                });
                return false;
              }
            }

            final editorial = editorialThemeOf(sheetBuilderContext);
            return SafeArea(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 620),
                child: EditorialSheet(
                  key: const Key('scoring-more-sheet'),
                  title: labels.more,
                  titleTrailing: compactHeight
                      ? Tooltip(
                          message: labels.cancel,
                          child: OutlinedButton(
                            key: const Key('more-close'),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.square(48),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.close),
                          ),
                        )
                      : null,
                  padding: compactHeight
                      ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
                      : const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  actions: compactHeight
                      ? const []
                      : [
                          OutlinedButton.icon(
                            key: const Key('more-close'),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close),
                            label: Text(labels.cancel),
                          ),
                        ],
                  child: Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (inlineFailure != null)
                            Container(
                              key: const Key('more-inline-error'),
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  sheetBuilderContext,
                                ).colorScheme.errorContainer,
                                border: Border(
                                  left: BorderSide(
                                    color: editorial.danger,
                                    width: 4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(inlineFailure!)),
                                  OutlinedButton(
                                    key: const Key('more-inline-retry'),
                                    onPressed: inlineRetry == null
                                        ? null
                                        : () =>
                                              unawaited(runMore(inlineRetry!)),
                                    child: Text(labels.retry),
                                  ),
                                ],
                              ),
                            ),
                          _moreSection(
                            sheetBuilderContext,
                            key: const Key('more-section-shooting'),
                            title: labels.shotDisplay,
                            children: [
                              _moreToggle(
                                sheetBuilderContext,
                                index: '01',
                                key: const Key('more-show-blue-misses'),
                                switchKey: const Key(
                                  'more-show-blue-misses-switch',
                                ),
                                label: labels.showMisses(TeamSide.blue),
                                value: _showBlueMissLocations,
                                onChanged: (value) {
                                  _setMissLocationsVisible(
                                    TeamSide.blue,
                                    value,
                                  );
                                  setSheetState(() {});
                                },
                              ),
                              _moreToggle(
                                sheetBuilderContext,
                                index: '02',
                                key: const Key('more-show-red-misses'),
                                switchKey: const Key(
                                  'more-show-red-misses-switch',
                                ),
                                label: labels.showMisses(TeamSide.red),
                                value: _showRedMissLocations,
                                onChanged: (value) {
                                  _setMissLocationsVisible(TeamSide.red, value);
                                  setSheetState(() {});
                                },
                              ),
                            ],
                          ),
                          _moreSection(
                            sheetBuilderContext,
                            key: const Key('more-section-free-throws'),
                            title: labels.freeThrows,
                            children: [
                              _moreAction(
                                sheetBuilderContext,
                                index: '01',
                                key: const Key('more-blue-free-throw-made'),
                                icon: Icons.check,
                                label: labels.freeThrow(TeamSide.blue, true),
                                enabled: _ordinaryActionsEnabled,
                                onTap: () => runMore(
                                  () => _recordFreeThrow(
                                    TeamSide.blue,
                                    true,
                                    rethrowFailure: true,
                                  ),
                                ),
                              ),
                              _moreAction(
                                sheetBuilderContext,
                                index: '02',
                                key: const Key('more-blue-free-throw-miss'),
                                icon: Icons.close,
                                label: labels.freeThrow(TeamSide.blue, false),
                                enabled: _ordinaryActionsEnabled,
                                onTap: () => runMore(
                                  () => _recordFreeThrow(
                                    TeamSide.blue,
                                    false,
                                    rethrowFailure: true,
                                  ),
                                ),
                              ),
                              _moreAction(
                                sheetBuilderContext,
                                index: '03',
                                key: const Key('more-red-free-throw-made'),
                                icon: Icons.check,
                                label: labels.freeThrow(TeamSide.red, true),
                                enabled: _ordinaryActionsEnabled,
                                onTap: () => runMore(
                                  () => _recordFreeThrow(
                                    TeamSide.red,
                                    true,
                                    rethrowFailure: true,
                                  ),
                                ),
                              ),
                              _moreAction(
                                sheetBuilderContext,
                                index: '04',
                                key: const Key('more-red-free-throw-miss'),
                                icon: Icons.close,
                                label: labels.freeThrow(TeamSide.red, false),
                                enabled: _ordinaryActionsEnabled,
                                onTap: () => runMore(
                                  () => _recordFreeThrow(
                                    TeamSide.red,
                                    false,
                                    rethrowFailure: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _moreSection(
                            sheetBuilderContext,
                            key: const Key('more-section-match-state'),
                            title: labels.matchStatus,
                            children: [
                              _moreAction(
                                sheetBuilderContext,
                                index: '01',
                                key: const Key('more-possession-blue'),
                                icon: Icons.swap_horiz,
                                label: labels.possession(TeamSide.blue),
                                enabled: _ordinaryActionsEnabled,
                                onTap: () => runMore(
                                  () => _recordPossession(
                                    TeamSide.blue,
                                    rethrowFailure: true,
                                  ),
                                ),
                              ),
                              _moreAction(
                                sheetBuilderContext,
                                index: '02',
                                key: const Key('more-possession-red'),
                                icon: Icons.swap_horiz,
                                label: labels.possession(TeamSide.red),
                                enabled: _ordinaryActionsEnabled,
                                onTap: () => runMore(
                                  () => _recordPossession(
                                    TeamSide.red,
                                    rethrowFailure: true,
                                  ),
                                ),
                              ),
                              if (_controller.timerEnabled && clock != null)
                                if (clock.isRunning)
                                  _moreAction(
                                    sheetBuilderContext,
                                    index: '03',
                                    key: const Key('more-pause'),
                                    icon: Icons.pause,
                                    label: labels.pause,
                                    enabled: _ordinaryActionsEnabled,
                                    onTap: () => runMore(
                                      () => _pause(rethrowFailure: true),
                                    ),
                                  )
                                else
                                  _moreAction(
                                    sheetBuilderContext,
                                    index: '03',
                                    key: const Key('more-resume'),
                                    icon: Icons.play_arrow,
                                    label: labels.resume,
                                    enabled: _ordinaryActionsEnabled,
                                    onTap: () => runMore(
                                      () => _resume(rethrowFailure: true),
                                    ),
                                  ),
                            ],
                          ),
                          _moreSection(
                            sheetBuilderContext,
                            key: const Key('more-section-notes-records'),
                            title: labels.records,
                            children: [
                              _moreAction(
                                sheetBuilderContext,
                                index: '01',
                                key: const Key('more-note'),
                                icon: Icons.notes,
                                label: labels.note,
                                enabled: _ordinaryActionsEnabled,
                                onTap: () => runMore(
                                  () => _enterNote(rethrowFailure: true),
                                ),
                              ),
                              _moreAction(
                                sheetBuilderContext,
                                index: '02',
                                key: const Key('more-custom'),
                                icon: Icons.add_circle_outline,
                                label: labels.custom,
                                enabled: _ordinaryActionsEnabled,
                                onTap: () => runMore(
                                  () => _enterCustom(rethrowFailure: true),
                                ),
                              ),
                            ],
                          ),
                          _moreSection(
                            sheetBuilderContext,
                            key: const Key('more-section-match'),
                            title: labels.match,
                            children: [
                              _moreAction(
                                sheetBuilderContext,
                                index: '01',
                                key: const Key('more-replay'),
                                icon: Icons.query_stats,
                                label: labels.replay,
                                enabled:
                                    widget.onOpenReplay != null &&
                                    _ordinaryActionsEnabled &&
                                    _controller
                                            .state
                                            .locationSupplementWindow ==
                                        null,
                                onTap: () => runMore(() async => _openReplay()),
                              ),
                              _moreAction(
                                sheetBuilderContext,
                                index: '02',
                                key: const Key('more-quick-guide'),
                                icon: Icons.help_outline,
                                label:
                                    (AppLocalizations.of(sheetBuilderContext) ??
                                            AppLocalizationsZh())
                                        .v2GuideTitle,
                                enabled: true,
                                onTap: () async {
                                  Navigator.of(sheetBuilderContext).pop();
                                  setState(() => _guideVisible = true);
                                  return true;
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool get _ordinaryActionsEnabled =>
      !_decisionControlsDeferred(_controller.state) &&
      _controller.state.pendingLocation == null &&
      _controller.state.courtFirstShotDraft == null;

  Widget _moreSection(
    BuildContext sheetContext, {
    required Key key,
    required String title,
    required List<Widget> children,
  }) {
    final editorial = editorialThemeOf(sheetContext);
    return Container(
      key: key,
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: editorial.ink, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(sheetContext).textTheme.labelLarge?.copyWith(
                color: editorial.mutedInk,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _moreAction(
    BuildContext sheetContext, {
    required String index,
    required Key key,
    required IconData icon,
    required String label,
    required bool enabled,
    required Future<bool> Function() onTap,
    bool destructive = false,
  }) {
    final editorial = editorialThemeOf(sheetContext);
    final row = EditorialIndexRow(
      key: key,
      index: index,
      title: label,
      trailing: Icon(
        icon,
        color: destructive ? editorial.danger : editorial.mutedInk,
      ),
      onTap: enabled ? () => unawaited(onTap()) : null,
    );
    if (enabled) return row;

    final theme = Theme.of(sheetContext);
    final disabledEditorial = editorial.copyWith(
      ink: editorial.mutedInk,
      rule: editorial.mutedInk,
    );
    final disabledExtensions = Map<Object, ThemeExtension<dynamic>>.of(
      theme.extensions,
    )..[HoopitoEditorialTheme] = disabledEditorial;
    return Semantics(
      button: true,
      enabled: false,
      child: Opacity(
        opacity: 0.48,
        child: Theme(
          data: theme.copyWith(extensions: disabledExtensions.values),
          child: row,
        ),
      ),
    );
  }

  Widget _moreToggle(
    BuildContext sheetContext, {
    required String index,
    required Key key,
    required Key switchKey,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final status = value
        ? _localizations(sheetContext).scoringDisplayShown
        : _localizations(sheetContext).scoringDisplayHidden;
    final semantic = '$label, $status';
    return Semantics(
      label: semantic,
      button: true,
      toggled: value,
      child: ExcludeSemantics(
        child: EditorialIndexRow(
          key: key,
          index: index,
          title: label,
          subtitle: value
              ? _localizations(sheetContext).scoringDisplayShown
              : _localizations(sheetContext).scoringDisplayHidden,
          trailing: Switch(key: switchKey, value: value, onChanged: onChanged),
          onTap: () => onChanged(!value),
        ),
      ),
    );
  }

  Future<bool> _pause({
    bool rethrowFailure = false,
    VoidCallback? onFailurePresented,
  }) async {
    final generation = _actionGeneration;
    final controller = _controller;
    try {
      final accepted = await controller.pauseCommitted();
      if (!_isCurrentAction(generation, controller)) return false;
      if (accepted) _notifyCommitted();
      return accepted;
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return false;
      if (rethrowFailure) throw _moreFailure(failure);
      onFailurePresented?.call();
      _showCommandFailure(failure);
      return false;
    }
  }

  Future<bool> _resume({bool rethrowFailure = false}) async {
    final generation = _actionGeneration;
    final controller = _controller;
    try {
      final accepted = await controller.resumeCommitted();
      if (!_isCurrentAction(generation, controller)) return false;
      if (accepted) _notifyCommitted();
      return accepted;
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return false;
      if (rethrowFailure) throw _moreFailure(failure);
      _showCommandFailure(failure);
      return false;
    }
  }

  Future<bool> _enterNote({bool rethrowFailure = false}) async {
    final generation = _actionGeneration;
    final controller = _controller;
    final labels = _labels(context);
    final note = await _showTextEntry(
      title: labels.note,
      hint: labels.noteHint,
      confirm: labels.recordNote,
    );
    if (note == null || !_isCurrentAction(generation, controller)) return false;
    try {
      final accepted = await controller.recordNoteCommitted(note);
      if (!_isCurrentAction(generation, controller)) return false;
      if (accepted) _notifyCommitted();
      return accepted;
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return false;
      if (rethrowFailure) throw _moreFailure(failure);
      _showCommandFailure(failure);
      return false;
    }
  }

  Future<bool> _enterCustom({bool rethrowFailure = false}) async {
    final generation = _actionGeneration;
    final controller = _controller;
    final labels = _labels(context);
    final label = await _showTextEntry(
      title: labels.custom,
      hint: labels.eventLabel,
      confirm: labels.recordEvent,
    );
    if (label == null || !_isCurrentAction(generation, controller)) {
      return false;
    }
    try {
      final accepted = await controller.recordCustomCommitted(label: label);
      if (!_isCurrentAction(generation, controller)) return false;
      if (accepted) _notifyCommitted();
      return accepted;
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return false;
      if (rethrowFailure) throw _moreFailure(failure);
      _showCommandFailure(failure);
      return false;
    }
  }

  Future<String?> _showTextEntry({
    required String title,
    required String hint,
    required String confirm,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _TextEntryDialog(
        title: title,
        hint: hint,
        confirm: confirm,
        cancel: _labels(dialogContext).cancel,
      ),
    );
  }

  Future<void> _continueDecision() async {
    final action = widget.onContinueDecision;
    if (action == null || _decisionBusy) return;
    await _attemptContinueDecision(
      action,
      retryAction: action,
      generation: _actionGeneration,
      controller: _controller,
    );
  }

  Future<void> _attemptContinueDecision(
    Future<void> Function() action, {
    required Future<void> Function() retryAction,
    required int generation,
    required ScoringController controller,
  }) async {
    if (!_isCurrentAction(generation, controller)) return;
    setState(() => _decisionBusy = true);
    try {
      await action();
      if (!_isCurrentAction(generation, controller)) return;
      _notifyCommitted();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } on MatchCommandFailure catch (failure) {
      if (!_isCurrentAction(generation, controller)) return;
      final retry = failure.canRetry
          ? () async {
              await failure.retry();
            }
          : retryAction;
      _showContinueFailure(
        retry,
        generation: generation,
        controller: controller,
      );
    } on Object {
      if (!_isCurrentAction(generation, controller)) return;
      _showContinueFailure(
        retryAction,
        generation: generation,
        controller: controller,
      );
    } finally {
      if (_isCurrentAction(generation, controller)) {
        setState(() => _decisionBusy = false);
      }
    }
  }

  void _showContinueFailure(
    Future<void> Function() retry, {
    required int generation,
    required ScoringController controller,
  }) {
    if (!_isCurrentAction(generation, controller)) return;
    final labels = _labels(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('scoring-decision-failure'),
          content: Text(labels.failureRetry),
          action: SnackBarAction(
            label: labels.retry,
            onPressed: () => unawaited(
              _attemptContinueDecision(
                retry,
                retryAction: retry,
                generation: generation,
                controller: controller,
              ),
            ),
          ),
        ),
      );
  }

  Future<bool> _confirmFinishDecision({bool rethrowFailure = false}) async {
    final generation = _actionGeneration;
    final controller = _controller;
    final decision = controller.state.decision;
    if (!_canFinish ||
        decision?.canFinish == false ||
        _decisionBusy ||
        _decisionControlsDeferred(controller.state)) {
      return false;
    }
    final state = _controller.state;
    final hasDraft =
        state.pendingLocation != null || state.courtFirstShotDraft != null;
    final redScore = decision?.redScore ?? state.score.redScore;
    final blueScore = decision?.blueScore ?? state.score.blueScore;
    final l10n = _localizations(context);
    final failureMessage = _labels(context).failureRetry;
    final coverage = await confirmRecordingCoverage(
      context,
      title: l10n.confirmFinalScoreTitle,
      scoreLine: l10n.finalScoreLine(
        state.blueName,
        blueScore,
        state.redName,
        redScore,
      ),
      draftNotice: hasDraft ? _labels(context).pendingPauseExitBody : null,
      confirmLabel: l10n.finishMatch,
      cancelKey: const Key('scoring-finish-cancel'),
      confirmKey: const Key('scoring-finish-confirm'),
    );
    if (coverage == null || !_isCurrentAction(generation, controller)) {
      return false;
    }
    final coveredFinish = widget.onFinishWithCoverage;
    final Future<void> Function(int, int) finish = coveredFinish == null
        ? widget.onFinishDecision!
        : (red, blue) => coveredFinish(red, blue, coverage);
    setState(() => _decisionBusy = true);
    try {
      await finish(redScore, blueScore);
      if (!_isCurrentAction(generation, controller)) return false;
      if (hasDraft) {
        final discarded = state.pendingLocation != null
            ? controller.cancelLocateLastUnlocatedShot()
            : controller.cancelCourtFirstShot();
        if (!discarded || !_isCurrentAction(generation, controller)) {
          return false;
        }
      }
      _notifyCommitted();
      return true;
    } on Object {
      if (!_isCurrentAction(generation, controller)) return false;
      if (rethrowFailure) {
        throw _MoreActionFailure(
          message: failureMessage,
          retry: () => _finishDecisionWithoutConfirmation(
            finish: finish,
            redScore: redScore,
            blueScore: blueScore,
            rethrowFailure: true,
            generation: generation,
            controller: controller,
          ),
        );
      }
      _showActionRejected(failureMessage);
      return false;
    } finally {
      if (_isCurrentAction(generation, controller)) {
        setState(() => _decisionBusy = false);
      }
    }
  }

  Future<bool> _finishDecisionWithoutConfirmation({
    required Future<void> Function(int redScore, int blueScore) finish,
    required int redScore,
    required int blueScore,
    required bool rethrowFailure,
    required int generation,
    required ScoringController controller,
  }) async {
    if (!_isCurrentAction(generation, controller)) return false;
    final failureMessage = _labels(context).failureRetry;
    setState(() => _decisionBusy = true);
    try {
      await finish(redScore, blueScore);
      if (!_isCurrentAction(generation, controller)) return false;
      _notifyCommitted();
      return true;
    } on Object {
      if (!_isCurrentAction(generation, controller)) return false;
      if (rethrowFailure) {
        throw _MoreActionFailure(
          message: failureMessage,
          retry: () => _finishDecisionWithoutConfirmation(
            finish: finish,
            redScore: redScore,
            blueScore: blueScore,
            rethrowFailure: true,
            generation: generation,
            controller: controller,
          ),
        );
      }
      _showActionRejected(failureMessage);
      return false;
    } finally {
      if (_isCurrentAction(generation, controller)) {
        setState(() => _decisionBusy = false);
      }
    }
  }

  bool _openReplay() {
    if (_controller.state.pendingLocation != null ||
        _controller.state.courtFirstShotDraft != null ||
        _controller.state.locationSupplementWindow != null) {
      _showActionRejected(_localizations(context).scoringResolvePending);
      return false;
    }
    widget.onOpenReplay?.call();
    return widget.onOpenReplay != null;
  }

  void _notifyCommitted() {
    final callback = widget.onActionCommitted;
    if (callback != null) unawaited(Future<void>.sync(callback));
  }

  AppLocalizations _localizations(BuildContext context) =>
      AppLocalizations.of(context) ?? AppLocalizationsZh();

  String _localizedHint(AppLocalizations l10n, RuleHint hint) {
    return switch (hint.messageKey) {
      'targetReached' => l10n.ruleTargetReached,
      'winByTwoRequired' => l10n.ruleWinByTwoRequired,
      'matchPoint' => l10n.ruleMatchPoint,
      'possessionChange' when hint.suggestedSide != null =>
        '${_localizedSide(l10n, hint.suggestedSide!)}${l10n.rulePossessionSuggested}',
      'possessionChange' => l10n.rulePossessionSuggested,
      _ => hint.message,
    };
  }

  String _localizedSide(AppLocalizations l10n, TeamSide side) {
    return side == TeamSide.blue ? l10n.pregameBlue : l10n.pregameRed;
  }

  void _showActionRejected(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('scoring-action-rejected'),
        content: Text(message),
      ),
    );
  }

  void _showCommandFailure(MatchCommandFailure failure) {
    if (!mounted) return;
    final generation = _actionGeneration;
    final controller = _controller;
    final messenger = ScaffoldMessenger.of(context);
    var consumed = false;
    var inFlight = false;
    Future<void> retry() async {
      if (consumed || inFlight) return;
      inFlight = true;
      try {
        final accepted = await _retryCommand(
          failure,
          generation: generation,
          controller: controller,
        );
        if (!accepted) return;
        consumed = true;
        if (_isCurrentAction(generation, controller)) {
          messenger.removeCurrentSnackBar();
        }
      } finally {
        inFlight = false;
      }
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_labels(context).failureRetry),
          action: failure.canRetry
              ? SnackBarAction(
                  label: _labels(context).retry,
                  onPressed: () => unawaited(retry()),
                )
              : null,
        ),
      );
  }

  Future<bool> _retryCommand(
    MatchCommandFailure failure, {
    required int generation,
    required ScoringController controller,
  }) async {
    if (!_isCurrentAction(generation, controller)) return false;
    try {
      final result = await controller.retryCommandWithReceipt(failure);
      if (!_isCurrentAction(generation, controller)) return false;
      if (result.accepted) {
        if (failure.command is! PauseMatchCommand &&
            failure.command is! ResumeMatchCommand &&
            controller.courtFirstShotDraft != null) {
          controller.cancelCourtFirstShot();
        }
        final receipt = result.receipt;
        if (receipt != null) {
          _submitReceiptMotion(
            receipt,
            _scoreButtonCenter(receipt.side, receipt.points),
          );
        }
        _notifyCommitted();
      }
      return result.accepted;
    } on MatchCommandFailure catch (nextFailure) {
      if (!_isCurrentAction(generation, controller)) return false;
      _showCommandFailure(nextFailure);
      return false;
    }
  }

  _MoreActionFailure _moreFailure(MatchCommandFailure failure) {
    final generation = _actionGeneration;
    final controller = _controller;
    return _MoreActionFailure(
      message: _labels(context).failureRetry,
      retry: failure.canRetry
          ? () => _retryMoreCommand(
              failure,
              generation: generation,
              controller: controller,
            )
          : null,
    );
  }

  Future<bool> _retryMoreCommand(
    MatchCommandFailure failure, {
    required int generation,
    required ScoringController controller,
  }) async {
    if (!_isCurrentAction(generation, controller)) return false;
    try {
      final accepted = await controller.retryCommand(failure);
      if (!_isCurrentAction(generation, controller)) return false;
      if (accepted) {
        if (failure.command is! PauseMatchCommand &&
            failure.command is! ResumeMatchCommand &&
            controller.courtFirstShotDraft != null) {
          controller.cancelCourtFirstShot();
        }
        _notifyCommitted();
      }
      return accepted;
    } on MatchCommandFailure catch (nextFailure) {
      if (!_isCurrentAction(generation, controller)) return false;
      throw _moreFailure(nextFailure);
    }
  }

  _ScoringLabels _labels(BuildContext context) =>
      _ScoringLabels(_localizations(context));

  bool _decisionControlsDeferred(MatchScoringState state) =>
      state.decision != null && state.locationSupplementWindow != null;
}

enum _MatchControlAction { returnToScoring, pause, finish }

class _MoreActionFailure implements Exception {
  const _MoreActionFailure({required this.message, required this.retry});

  final String message;
  final Future<bool> Function()? retry;
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.state,
    required this.clock,
    required this.portrait,
    required this.onLeave,
    required this.onUndo,
    required this.onFoul,
    required this.foulEnabled,
    required this.onMore,
    required this.onFinish,
    required this.labels,
  });

  final MatchScoringState state;
  final ClockProjection? clock;
  final bool portrait;
  final VoidCallback onLeave;
  final VoidCallback onUndo;
  final ValueChanged<TeamSide> onFoul;
  final bool foulEnabled;
  final VoidCallback onMore;
  final VoidCallback? onFinish;
  final _ScoringLabels labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blue = teamColorForScheme(
      TeamSide.blue,
      scheme,
      background: HoopitoColors.ink,
    );
    final red = teamColorForScheme(
      TeamSide.red,
      scheme,
      background: HoopitoColors.ink,
    );
    final editorial = editorialThemeOf(context);
    final clockLabel = clock == null
        ? labels.noTimer
        : '${clock!.phase == ClockPhase.overtime ? '${labels.l10n.scoringOvertime} ' : ''}${_formatSeconds(clock!.displaySeconds)}';
    final status = clock == null
        ? labels.timerNotConfigured
        : clock!.isRegulationExpired
        ? labels.regulationExpired
        : clock!.isRunning
        ? labels.clockRunning
        : labels.clockPaused;
    Widget action({
      required Key key,
      required String tooltip,
      required IconData icon,
      required VoidCallback onPressed,
    }) {
      return Tooltip(
        message: tooltip,
        child: OutlinedButton(
          key: key,
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            foregroundColor: Colors.white,
            backgroundColor: HoopitoColors.ink,
            elevation: 0,
            side: const BorderSide(color: Color(0xFF777D82)),
            shape: const BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(7)),
            ),
          ),
          child: Icon(icon),
        ),
      );
    }

    Widget foulSelector() {
      return MenuAnchor(
        alignmentOffset: const Offset(0, 4),
        menuChildren: [
          for (final side in const [TeamSide.blue, TeamSide.red])
            MenuItemButton(
              key: Key('scoring-foul-${side.name}'),
              onPressed: () => onFoul(side),
              style: MenuItemButton.styleFrom(
                minimumSize: const Size(156, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    color: side == TeamSide.blue ? blue : red,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    labels.foulFor(side),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
        builder: (context, controller, child) => Tooltip(
          message: labels.foul,
          child: OutlinedButton(
            key: const Key('scoring-foul'),
            onPressed: foulEnabled ? controller.open : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              foregroundColor: editorial.arenaAccent,
              backgroundColor: HoopitoColors.ink,
              disabledForegroundColor: Colors.white38,
              elevation: 0,
              side: BorderSide(
                color: foulEnabled
                    ? editorial.arenaAccent
                    : const Color(0xFF777D82),
              ),
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(7)),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                labels.foul,
                maxLines: 1,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      key: const Key('scoring-scoreboard'),
      color: HoopitoColors.ink,
      child: SizedBox(
        height: portrait ? 104 : 56,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < 900;
            final sideWidth = _landscapeSideWidth(width);
            final finishWidth = compact ? 48.0 : 96.0;
            final desiredClockWidth = (width * 0.22).clamp(
              compact ? 72.0 : 112.0,
              compact ? 104.0 : 180.0,
            );
            final landscapeClockMax =
                ((width - sideWidth) - width / 2 - (96 + finishWidth)) * 2;
            final clockMax = portrait
                ? (compact ? 104.0 : 180.0)
                : landscapeClockMax.clamp(
                    compact ? 72.0 : 112.0,
                    compact ? 104.0 : 180.0,
                  );
            final clockWidth = desiredClockWidth.clamp(
              compact ? 72.0 : 112.0,
              clockMax,
            );
            final clockLeft = (width - clockWidth) / 2;
            final clockRight = clockLeft + clockWidth;
            final portraitActionsLeft = (width - 240) / 2;
            final leaveLeft = portrait ? portraitActionsLeft : clockLeft - 96;
            final undoLeft = leaveLeft + 48;
            final foulLeft = portrait ? undoLeft + 48 : clockRight;
            final moreLeft = foulLeft + 48;
            final finishLeft = moreLeft + 48;
            final resolvedFinishWidth = portrait ? 48.0 : finishWidth;
            final sideCenter = portrait ? width / 4 : sideWidth / 2;
            final teamWidth = portrait
                ? ((clockLeft - sideCenter) * 2).clamp(48.0, width / 2)
                : sideWidth;
            final teamLeft = sideCenter - teamWidth / 2;
            final scoreBottom = portrait ? 52.0 : 4.0;
            final actionTop = portrait ? 52.0 : 4.0;

            return Stack(
              children: [
                Positioned(
                  left: teamLeft,
                  top: 4,
                  bottom: scoreBottom,
                  width: teamWidth,
                  child: _ScoreLabel(
                    side: TeamSide.blue,
                    name: state.blueName,
                    score: state.score.blueScore,
                    color: blue,
                    alignment: Alignment.center,
                  ),
                ),
                Positioned(
                  left: leaveLeft,
                  top: actionTop,
                  bottom: 4,
                  width: 48,
                  child: action(
                    key: const Key('scoring-leave'),
                    tooltip: labels.back,
                    icon: Icons.arrow_back,
                    onPressed: onLeave,
                  ),
                ),
                Positioned(
                  left: undoLeft,
                  top: actionTop,
                  bottom: 4,
                  width: 48,
                  child: action(
                    key: const Key('scoring-undo'),
                    tooltip: labels.undo,
                    icon: Icons.undo,
                    onPressed: onUndo,
                  ),
                ),
                Positioned(
                  left: clockLeft,
                  top: 4,
                  bottom: scoreBottom,
                  width: clockWidth,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              clockLabel,
                              maxLines: 1,
                              semanticsLabel: labels.matchTime(clockLabel),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ),
                        ),
                        if (!compact)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              status,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: foulLeft,
                  top: actionTop,
                  bottom: 4,
                  width: 48,
                  child: foulSelector(),
                ),
                Positioned(
                  left: moreLeft,
                  top: actionTop,
                  bottom: 4,
                  width: 48,
                  child: action(
                    key: const Key('scoring-more'),
                    tooltip: labels.more,
                    icon: Icons.more_vert,
                    onPressed: onMore,
                  ),
                ),
                Positioned(
                  left: finishLeft,
                  top: actionTop,
                  bottom: 4,
                  width: resolvedFinishWidth,
                  child: Tooltip(
                    message: labels.finish,
                    child: FilledButton(
                      key: const Key('scoring-finish'),
                      onPressed: onFinish,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 2 : 12,
                        ),
                        foregroundColor: HoopitoColors.ink,
                        backgroundColor: editorial.arenaAccent,
                        elevation: 0,
                        shape: const BeveledRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(7)),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          compact ? labels.finishShort : labels.finish,
                          maxLines: 1,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: teamLeft,
                  top: 4,
                  bottom: scoreBottom,
                  width: teamWidth,
                  child: _ScoreLabel(
                    side: TeamSide.red,
                    name: state.redName,
                    score: state.score.redScore,
                    color: red,
                    alignment: Alignment.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreLabel extends StatelessWidget {
  const _ScoreLabel({
    required this.side,
    required this.name,
    required this.score,
    required this.color,
    required this.alignment,
  });
  final TeamSide side;
  final String name;
  final int score;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final label = side == TeamSide.blue ? '$name $score' : '$score $name';
    final scoreText = AnimatedSwitcher(
      duration: editorialMotionDuration(
        context,
        standard:
            Theme.of(
              context,
            ).extension<HoopitoMotionTheme>()?.scoreTransition ??
            const Duration(milliseconds: 180),
      ),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.65),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
      child: Text(
        '$score',
        key: ValueKey(score),
        maxLines: 1,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: color,
          fontFamily: HoopitoTypography.displayFamily,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    final nameText = RichText(
      text: TextSpan(
        text: name,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
      maxLines: 1,
    );
    return Semantics(
      label: label,
      child: Align(
        alignment: alignment,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: 0,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: alignment,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: side == TeamSide.blue
                        ? [nameText, const SizedBox(width: 4), scoreText]
                        : [scoreText, const SizedBox(width: 4), nameText],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.hint,
    required this.confirm,
    required this.cancel,
  });
  final String title;
  final String hint;
  final String confirm;
  final String cancel;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  late final TextEditingController _editingController;

  @override
  void initState() {
    super.initState();
    _editingController = TextEditingController();
  }

  @override
  void dispose() {
    _editingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('text-entry-field'),
        controller: _editingController,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          key: const Key('text-entry-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancel),
        ),
        FilledButton(
          key: const Key('text-entry-confirm'),
          onPressed: () =>
              Navigator.of(context).pop(_editingController.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

class _ScoringLabels {
  _ScoringLabels(this.l10n);

  final AppLocalizations l10n;
  String get back => l10n.scoringBackToScoringList;
  String get undo => l10n.scoringUndo;
  String get foul => l10n.scoringFoul;
  String get more => l10n.scoringMore;
  String get noTimer => l10n.scoringNoTimer;
  String get timerNotConfigured => l10n.scoringTimerNotConfigured;
  String get clockRunning => l10n.scoringClockRunning;
  String get clockPaused => l10n.scoringClockPaused;
  String get regulationExpired => l10n.scoringRegulationExpired;
  String get shotDisplay => l10n.scoringShotDisplayGroup;
  String get freeThrows => l10n.scoringFreeThrowsGroup;
  String get matchStatus => l10n.scoringMatchStatusGroup;
  String get records => l10n.scoringNotesCustomRecordsGroup;
  String get match => l10n.scoringMatchGroup;
  String get note => l10n.scoringNote;
  String get custom => l10n.scoringCustom;
  String get pause => l10n.scoringPause;
  String get resume => l10n.scoringResume;
  String get replay => l10n.scoringReplay;
  String get finish => l10n.finishMatch;
  String get finishShort => l10n.scoringFinishShort;
  String get matchControlsTitle => l10n.scoringMatchControlsTitle;
  String get matchControlsBody => l10n.scoringMatchControlsBody;
  String get returnToScoring => l10n.scoringReturnToScoring;
  String get pauseMatch => l10n.scoringPauseMatch;
  String get matchPausedTitle => l10n.scoringMatchPausedTitle;
  String get matchPausedBody => l10n.scoringMatchPausedBody;
  String get returnHome => l10n.scoringReturnHome;
  String get continueMatch => l10n.continueMatch;
  String get pendingPauseExitBody => l10n.scoringPendingPauseExitBody;
  String get discardDraft => l10n.scoringDiscardDraft;
  String get chooseScoringSide => l10n.scoringChooseScoringSide;
  String get supplementExpired => l10n.scoringSupplementExpired;
  String get actionRejected => l10n.scoringActionRejected;
  String get failureRetry => l10n.actionFailedRetry;
  String get retry => l10n.historyRetry;
  String get cancel => l10n.cancelAction;
  String get stay => l10n.scoringStay;
  String get cancelAndLeave => l10n.scoringCancelLocationLeave;
  String get pendingTitle => l10n.scoringPendingLocationTitle;
  String get pendingBody => l10n.scoringPendingLocationBody;
  String get noteHint => l10n.scoringNoteHint;
  String get recordNote => l10n.scoringRecordNote;
  String get eventLabel => l10n.scoringEventLabel;
  String get recordEvent => l10n.scoringRecordEvent;
  String sideName(TeamSide side) =>
      side == TeamSide.blue ? l10n.pregameBlue : l10n.pregameRed;
  String foulFor(TeamSide side) => l10n.scoringFoulForSide(sideName(side));
  String showMisses(TeamSide side) =>
      l10n.scoringShowMissMarkers(sideName(side));
  String freeThrow(TeamSide side, bool made) {
    return switch ((side, made)) {
      (TeamSide.blue, true) => l10n.scoringBlueFreeThrowMade,
      (TeamSide.blue, false) => l10n.scoringBlueFreeThrowMissed,
      (TeamSide.red, true) => l10n.scoringRedFreeThrowMade,
      (TeamSide.red, false) => l10n.scoringRedFreeThrowMissed,
    };
  }

  String possession(TeamSide side) => side == TeamSide.blue
      ? l10n.scoringPossessionBlue
      : l10n.scoringPossessionRed;
  String supplementPrompt(String side, int points, int seconds) =>
      l10n.scoringSupplementPrompt(points, seconds, side);
  String missSupplementPrompt(String side, int seconds) =>
      l10n.scoringMissSupplementPrompt(seconds, side);
  String matchTime(String value) => l10n.scoringMatchTime(value);
}

String _formatSeconds(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  return '${(safe ~/ 60).toString().padLeft(2, '0')}:${(safe % 60).toString().padLeft(2, '0')}';
}
