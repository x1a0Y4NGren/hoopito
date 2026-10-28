import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hoopito/app/design_system/editorial_motion.dart';
import 'package:hoopito/app/design_system/editorial_tokens.dart';
import 'package:hoopito/app/entry/entry_creature.dart';
import 'package:hoopito/app/entry/entry_brand_image.dart';
import 'package:hoopito/app/entry/entry_frame_probe.dart';
import 'package:hoopito/app/entry/entry_renderer_ready.dart';
import 'package:hoopito/core/diagnostics/startup_diagnostics.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';

const hoopitoEntryOverlayKey = Key('hoopito-entry-overlay');
const hoopitoEntrySceneKey = Key('hoopito-entry-scene');
const hoopitoEntryWaitingKey = Key('hoopito-entry-waiting');

enum EntryMotionMode { standard, reduced, disabled }

enum EntryStartupStatus { loading, ready, failure, legacy }

abstract final class HoopitoEntryTimeline {
  static const total = Duration(milliseconds: 1000);
  static const handoffEnd = Duration(milliseconds: 60);
  static const anticipationEnd = Duration(milliseconds: 150);
  static const flightPeak = Duration(milliseconds: 330);
  static const landing = Duration(milliseconds: 480);
  static const reboundEnd = Duration(milliseconds: 620);
  static const rippleEnd = Duration(milliseconds: 760);
  static const fadeStart = Duration(milliseconds: 860);
  static const imageWait = Duration(milliseconds: 100);
  static const rendererWait = Duration(seconds: 2);
  static const presentationWait = Duration(seconds: 2);
  static const waitingHint = Duration(seconds: 2);
}

typedef EntryMotionPreferenceLoader = Future<MotionPreference> Function();

/// Returns a decoded image owned by the gate. Late results are also disposed.
typedef EntryImageLoader = Future<ui.Image> Function();
typedef EntryRendererReadyLoader = Future<void> Function();

class EntryPlaybackSession {
  bool _claimed = false;

  bool claim() {
    if (_claimed) return false;
    _claimed = true;
    return true;
  }
}

class HoopitoEntryGate extends StatefulWidget {
  const HoopitoEntryGate({
    required this.child,
    this.startupStatus = EntryStartupStatus.ready,
    this.waitingLabel,
    this.motionPreferenceLoader,
    this.imageLoader,
    this.rendererReadyLoader,
    this.presentationReadyLoader,
    this.playbackSession,
    this.onRevealed,
    super.key,
  });

  final Widget child;
  final EntryStartupStatus startupStatus;
  final String? waitingLabel;
  final EntryMotionPreferenceLoader? motionPreferenceLoader;
  final EntryImageLoader? imageLoader;
  final EntryRendererReadyLoader? rendererReadyLoader;
  final EntryRendererReadyLoader? presentationReadyLoader;
  final EntryPlaybackSession? playbackSession;

  /// Runs once after ready local content is visible, including hidden or
  /// skipped playback. Auxiliary startup work must not delay this handoff.
  final VoidCallback? onRevealed;

  @override
  State<HoopitoEntryGate> createState() => _HoopitoEntryGateState();
}

class _HoopitoEntryGateState extends State<HoopitoEntryGate>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  final _probe = const bool.fromEnvironment('HOOPITO_ENTRY_PROFILE')
      ? EntryFrameProbe()
      : null;
  HoopitoMotionTheme _motion = const HoopitoMotionTheme.light();
  EntryMotionMode? _mode;
  ui.Image? _image;
  Timer? _hintTimer;
  bool _decisionStarted = false;
  bool _visible = true;
  bool _childMounted = false;
  bool _performanceDone = false;
  bool _exiting = false;
  bool _skipping = false;
  bool _skipRevealsContent = false;
  bool _showWaitingHint = false;
  bool _firstFrameDeferred = false;
  bool _revealScheduled = false;
  bool _revealNotified = false;
  double _skipFrom = 0;
  double _skipOpacity = 1;

  bool get _ready => widget.startupStatus == EntryStartupStatus.ready;
  bool get _terminal =>
      widget.startupStatus == EntryStartupStatus.failure ||
      widget.startupStatus == EntryStartupStatus.legacy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: _motion.entry,
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_stageChild);
    if (widget.playbackSession?.claim() == false || _terminal) {
      _decisionStarted = true;
      _visible = false;
      _probe?.dispose();
    }
    _hintTimer = Timer(HoopitoEntryTimeline.waitingHint, () {
      if (mounted && _visible) setState(() => _showWaitingHint = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion =
        Theme.of(context).extension<HoopitoMotionTheme>() ??
        const HoopitoMotionTheme.light();
    final media = MediaQuery.maybeOf(context);
    if (media?.disableAnimations == true) {
      _decisionStarted = true;
      _controller.stop();
      _visible = false;
      _releaseFirstFrame();
      _retireImage();
      _probe?.dispose();
      return;
    }
    if (_decisionStarted) return;
    _decisionStarted = true;
    if (!WidgetsBinding.instance.firstFrameRasterized) {
      WidgetsBinding.instance.deferFirstFrame();
      _firstFrameDeferred = true;
    }
    unawaited(_prepare(reduced: media?.accessibleNavigation == true));
  }

  Future<void> _prepare({required bool reduced}) async {
    await _loadRendererReady();
    if (!mounted || !_visible || _skipping || _performanceDone) {
      _releaseFirstFrame();
      return;
    }
    // Both platform-backed preparation deadlines start after the surface.
    // On a first run the uncached preference reply also needs the UI thread.
    final preference = _loadPreference(reduced);
    final image = await _loadImage();
    final chosen = await preference;
    if (!mounted || !_visible || _skipping || _performanceDone) {
      image?.dispose();
      _releaseFirstFrame();
      return;
    }
    _image = image;
    _mode = chosen == MotionPreference.reduced || image == null
        ? EntryMotionMode.reduced
        : EntryMotionMode.standard;
    setState(() {});
    _releaseFirstFrame();
    // The first draw lets Android release its splash. Waiting before that draw
    // would deadlock the handoff; starting before the reply hides the jump.
    _probe?.mark('handoff');
    final presented = await _loadPresentationReady();
    if (!mounted || !_visible || _skipping || _performanceDone) return;
    if (!presented) {
      _mode = EntryMotionMode.reduced;
      setState(() {});
    }
    // Submit the matching handoff before the first animated vsync.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible && !_skipping && !_performanceDone) {
          unawaited(_play());
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<bool> _loadPresentationReady() async {
    final elapsed = _probe == null ? null : (Stopwatch()..start());
    var outcome = 'presented';
    try {
      await (widget.presentationReadyLoader ?? waitForEntryPresentation)()
          .timeout(HoopitoEntryTimeline.presentationWait);
      return true;
    } on TimeoutException {
      outcome = 'timeout';
    } on MissingPluginException {
      outcome = 'unavailable';
    } on Object {
      outcome = 'error';
    } finally {
      if (elapsed != null) {
        _probe?.preparation(
          'presentation',
          elapsedUs: elapsed.elapsedMicroseconds,
          outcome: outcome,
        );
      }
    }
    return false;
  }

  Future<void> _loadRendererReady() async {
    final elapsed = _probe == null ? null : (Stopwatch()..start());
    var outcome = 'ready';
    try {
      await (widget.rendererReadyLoader ?? waitForEntryRenderer)().timeout(
        HoopitoEntryTimeline.rendererWait,
        onTimeout: () => outcome = 'timeout',
      );
    } on MissingPluginException {
      // Hosts without this optional bridge retain the bounded image fallback.
      outcome = 'unavailable';
    } on Object {
      outcome = 'error';
    } finally {
      if (elapsed != null) {
        _probe?.preparation(
          'renderer',
          elapsedUs: elapsed.elapsedMicroseconds,
          outcome: outcome,
        );
      }
    }
  }

  Future<MotionPreference> _loadPreference(bool reduced) async {
    final elapsed = _probe == null ? null : (Stopwatch()..start());
    var outcome = reduced ? 'accessible_navigation' : 'standard';
    try {
      if (reduced) return MotionPreference.reduced;
      final preference =
          await (widget.motionPreferenceLoader?.call() ??
                  Future.value(MotionPreference.standard))
              .timeout(
                _motion.entryPreferenceWait,
                onTimeout: () {
                  outcome = 'timeout';
                  return MotionPreference.reduced;
                },
              );
      if (outcome != 'timeout') outcome = preference.name;
      return preference;
    } on Object {
      outcome = 'error';
      return MotionPreference.reduced;
    } finally {
      if (elapsed != null) {
        _probe?.preparation(
          'preference',
          elapsedUs: elapsed.elapsedMicroseconds,
          outcome: outcome,
        );
      }
    }
  }

  Future<ui.Image?> _loadImage() async {
    var accepting = true;
    final startedAt = StartupDiagnostics.start();
    final elapsed = Stopwatch()..start();
    var outcome = 'decoded';
    try {
      final load =
          widget.imageLoader ??
          () => decodeEntryBrandImage(
            devicePixelRatio: View.of(context).devicePixelRatio,
          );
      return await StartupDiagnostics.measureSync('image_loader_call', load)
          .then<ui.Image?>((image) {
            // A synchronous loader or UI stall can delay the Timer while the
            // source Future wins the callback race. Enforce the same deadline
            // against a monotonic clock before accepting that late image.
            if (!accepting ||
                elapsed.elapsed > HoopitoEntryTimeline.imageWait) {
              accepting = false;
              outcome = 'timeout';
              image.dispose();
              return null;
            }
            return image;
          })
          .timeout(
            HoopitoEntryTimeline.imageWait,
            onTimeout: () {
              StartupDiagnostics.end('image_timeout_callback', startedAt);
              accepting = false;
              outcome = 'timeout';
              return null;
            },
          );
    } on Object {
      accepting = false;
      outcome = 'error';
      return null;
    } finally {
      _probe?.preparation(
        'image',
        elapsedUs: elapsed.elapsedMicroseconds,
        outcome: outcome,
      );
    }
  }

  void _releaseFirstFrame() {
    if (!_firstFrameDeferred) return;
    _firstFrameDeferred = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  Future<void> _play() async {
    _probe?.mark('playing_${_mode?.name}');
    try {
      if (_mode == EntryMotionMode.standard) {
        await _controller
            .animateTo(
              .86,
              duration: Duration(
                microseconds: (_motion.entry.inMicroseconds * .86).round(),
              ),
            )
            .orCancel;
      } else {
        _controller.value = .86;
      }
      if (!mounted || !_visible || _skipping) return;
      _performanceDone = true;
      _probe?.mark('settled');
      _maybeExit();
    } on TickerCanceled {
      // Skip, accessibility, terminal startup and disposal cancel this run.
    }
  }

  void _stageChild() {
    if (!_ready || _childMounted || _skipping || _controller.value < .76) {
      return;
    }
    setState(() => _childMounted = true);
  }

  void _maybeExit() {
    if (!_visible || !_ready || !_performanceDone || _skipping || _exiting) {
      return;
    }
    _exiting = true;
    _probe?.mark('reveal');
    setState(() => _childMounted = true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_visible || _skipping) return;
      try {
        await _controller.animateTo(1, duration: _motion.entryReduced).orCancel;
        _finish();
      } on TickerCanceled {
        // A terminal startup state or disposal superseded the reveal.
      }
    });
  }

  @override
  void didUpdateWidget(covariant HoopitoEntryGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_terminal) {
      _controller.stop();
      _visible = false;
      _releaseFirstFrame();
      _retireImage();
      _probe?.dispose();
    } else if (_ready) {
      _stageChild();
      _maybeExit();
    } else if (_visible && (_exiting || _skipping)) {
      _controller.stop();
      _exiting = false;
      _skipping = false;
      _performanceDone = true;
      _mode = EntryMotionMode.reduced;
      _controller.value = .86;
    }
  }

  Future<void> _skip() async {
    if (!_visible || _skipping) return;
    _skipFrom = _controller.value;
    _skipOpacity = _entryOpacity(_skipFrom);
    _controller.stop();
    _skipping = true;
    _skipRevealsContent = _ready;
    _performanceDone = true;
    _probe?.mark('skip');
    _releaseFirstFrame();
    setState(() {
      _childMounted = _childMounted || _ready;
      _controller.value = 0;
    });
    try {
      final remaining = _exiting
          ? Duration(
              microseconds: (_motion.entry.inMicroseconds * (1 - _skipFrom))
                  .round(),
            )
          : _motion.entrySkip;
      await _controller
          .animateTo(
            1,
            duration: remaining < _motion.entrySkip
                ? remaining
                : _motion.entrySkip,
          )
          .orCancel;
      if (!mounted || !_visible) return;
      if (_skipRevealsContent) {
        _finish();
      } else {
        setState(() {
          _skipping = false;
          _mode = EntryMotionMode.reduced;
          _controller.value = .86;
        });
        _maybeExit();
      }
    } on TickerCanceled {
      // A terminal startup state or disposal superseded the skip.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _visible) {
      // Settle rather than restarting a decorative jump on return.
      unawaited(_skip());
    }
  }

  void _finish() {
    if (!mounted || !_visible) return;
    _hintTimer?.cancel();
    if (_probe != null) unawaited(_probe.finish());
    setState(() => _visible = false);
    _retireImage();
  }

  void _retireImage() {
    final image = _image;
    _image = null;
    if (image == null) return;
    // Let the last render object leave the tree before releasing its texture.
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _releaseFirstFrame();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _probe?.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _notifyRevealed();
    if (!_visible && !_childMounted) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_childMounted) widget.child,
        if (_visible)
          Positioned.fill(
            child: BlockSemantics(
              child: GestureDetector(
                key: hoopitoEntryOverlayKey,
                behavior: HitTestBehavior.opaque,
                onTap: _skip,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final skip = Curves.easeOutCubic.transform(
                      _controller.value,
                    );
                    return HoopitoEntryFrame(
                      key: hoopitoEntrySceneKey,
                      image: _image,
                      nativeHandoffPending: _firstFrameDeferred,
                      mode: _mode,
                      progress: _skipping ? _skipFrom : _controller.value,
                      motionStrength: _skipping ? 1 - skip : 1,
                      opacity: _skipping
                          ? (_skipRevealsContent
                                ? _skipOpacity * (1 - skip)
                                : 1)
                          : null,
                      waitingLabel: !_ready && _showWaitingHint
                          ? widget.waitingLabel
                          : null,
                      onRenderFallback: _probe == null
                          ? null
                          : () => _probe.mark('mesh_fallback'),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _notifyRevealed() {
    if (_visible ||
        !_ready ||
        _revealNotified ||
        _revealScheduled ||
        widget.onRevealed == null) {
      return;
    }
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted || _visible || !_ready || _revealNotified) return;
      _revealNotified = true;
      widget.onRevealed?.call();
    });
  }
}

class HoopitoEntryFrame extends StatelessWidget {
  const HoopitoEntryFrame({
    required this.mode,
    required this.progress,
    this.image,
    this.nativeHandoffPending = false,
    this.motionStrength = 1,
    this.opacity,
    this.waitingLabel,
    this.onRenderFallback,
    super.key,
  }) : assert(progress >= 0 && progress <= 1);

  final EntryMotionMode? mode;
  final double progress;
  final ui.Image? image;
  final bool nativeHandoffPending;
  final double motionStrength;
  final double? opacity;
  final String? waitingLabel;
  final VoidCallback? onRenderFallback;

  @override
  Widget build(BuildContext context) {
    final mark = ExcludeSemantics(
      child: RepaintBoundary(
        child: image == null
            ? (nativeHandoffPending
                  ? const SizedBox.square(dimension: 288)
                  : const _StaticBrand())
            : EntryCreature(
                image: image!,
                progress: mode == EntryMotionMode.standard ? progress : 0,
                motionStrength: motionStrength,
                onFallback: onRenderFallback,
              ),
      ),
    );
    return Opacity(
      opacity:
          opacity ??
          (mode == EntryMotionMode.disabled ? 0 : _entryOpacity(progress)),
      child: ColoredBox(
        color: HoopitoColors.ink,
        child: waitingLabel == null
            ? Center(
                child: OverflowBox(
                  minWidth: 288,
                  maxWidth: 288,
                  minHeight: 288,
                  maxHeight: 288,
                  child: mark,
                ),
              )
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: FittedBox(fit: BoxFit.scaleDown, child: mark),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          waitingLabel!,
                          key: hoopitoEntryWaitingKey,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: HoopitoColors.offWhite),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Used when animation is disabled or already consumed while startup continues.
class HoopitoStartupPlaceholder extends StatefulWidget {
  const HoopitoStartupPlaceholder({this.waitingLabel, super.key});

  final String? waitingLabel;

  @override
  State<HoopitoStartupPlaceholder> createState() =>
      _HoopitoStartupPlaceholderState();
}

class _HoopitoStartupPlaceholderState extends State<HoopitoStartupPlaceholder> {
  Timer? _timer;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(HoopitoEntryTimeline.waitingHint, () {
      if (mounted) setState(() => _showHint = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HoopitoEntryFrame(
    mode: null,
    progress: 0,
    waitingLabel: _showHint ? widget.waitingLabel : null,
  );
}

class _StaticBrand extends StatelessWidget {
  const _StaticBrand();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 288,
    child: Transform.scale(
      scale: .78,
      child: Image.asset(
        entryBrandAsset,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      ),
    ),
  );
}

double _entryOpacity(double progress) {
  final reveal = ((progress - .86) / .14).clamp(0.0, 1.0);
  return 1 - Curves.easeInOutCubic.transform(reveal);
}
