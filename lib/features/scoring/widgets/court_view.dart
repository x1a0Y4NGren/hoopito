import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/domain/value_objects/court_geometry.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/widgets/court_painter.dart';

export 'court_painter.dart'
    show EraserShotMarker, TransientShotMarker, FreeThrowCourtMarker;

enum CourtViewMode { readOnly, editable }

class CourtSelection {
  const CourtSelection({required this.point, required this.freeThrowEligible});
  final CourtPoint point;
  final bool freeThrowEligible;
}

CourtPoint pointFromLocal(Offset local, Size size) =>
    HalfCourtGeometry.pointFromLocal(local, size);

class CourtView extends StatefulWidget {
  const CourtView({
    required this.shotLocations,
    this.pendingLocation,
    this.detailedShotDraft,
    this.highlightedShotLocationId,
    this.locationPrompt,
    this.onPendingLocationChanged,
    this.onCourtPointTap,
    this.onCourtSelectionTap,
    this.onInvalidCourtPoint,
    this.onShotLocationTap,
    this.geometryKey,
    this.activeRegion,
    this.reduceMotion = false,
    this.highlightFreeThrowLine = false,
    this.freeThrowMarkers = const [],
    this.hiddenShotLocationIds = const <String>{},
    this.transientMarkers = const <TransientShotMarker>[],
    this.eraserMarkers = const <EraserShotMarker>[],
    this.mode = CourtViewMode.editable,
    super.key,
  });

  final List<ScoringShotLocation> shotLocations;
  final PendingShotLocation? pendingLocation;
  final DetailedShotDraft? detailedShotDraft;
  final String? highlightedShotLocationId;
  final String? locationPrompt;
  final ValueChanged<CourtPoint>? onPendingLocationChanged;
  final ValueChanged<CourtPoint>? onCourtPointTap;
  final ValueChanged<CourtSelection>? onCourtSelectionTap;
  final ValueChanged<CourtPoint>? onInvalidCourtPoint;
  final ValueChanged<String>? onShotLocationTap;
  final GlobalKey? geometryKey;
  final CourtRegion? activeRegion;
  final bool reduceMotion;
  final bool highlightFreeThrowLine;
  final List<FreeThrowCourtMarker> freeThrowMarkers;
  final Set<String> hiddenShotLocationIds;
  final List<TransientShotMarker> transientMarkers;
  final List<EraserShotMarker> eraserMarkers;
  final CourtViewMode mode;

  @override
  State<CourtView> createState() => _CourtViewState();
}

class _CourtViewState extends State<CourtView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
    value: .5,
  );
  final FocusNode _focus = FocusNode(debugLabel: 'court-location');
  CourtPoint? _cursor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant CourtView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRegion != widget.activeRegion ||
        (oldWidget.detailedShotDraft != null &&
            widget.detailedShotDraft == null)) {
      _cursor = null;
    }
    _syncPulse();
  }

  void _syncPulse() {
    final media = MediaQuery.maybeOf(context);
    final animate =
        widget.activeRegion != null &&
        widget.mode == CourtViewMode.editable &&
        !widget.reduceMotion &&
        !(media?.disableAnimations ?? false) &&
        !(media?.accessibleNavigation ?? false) &&
        TickerMode.valuesOf(context).enabled;
    if (animate) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = .5;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _freeThrowEligible(Offset local, Size size, CourtPoint point) {
    if (!CourtGeometry.contains(CourtRegion.insideArc, point)) return false;
    final court = HalfCourtGeometry.courtRectForSize(size);
    final start = HalfCourtGeometry.metersToOffset(
      court,
      CourtGeometry.centerX - CourtGeometry.freeThrowLineWidth / 2,
      CourtGeometry.freeThrowLineY,
    );
    final end = HalfCourtGeometry.metersToOffset(
      court,
      CourtGeometry.centerX + CourtGeometry.freeThrowLineWidth / 2,
      CourtGeometry.freeThrowLineY,
    );
    return Rect.fromPoints(start, end).inflate(24).contains(local);
  }

  bool _accepts(CourtPoint point, Offset local, Size size) {
    final region = widget.activeRegion;
    return region == null ||
        (region == CourtRegion.freeThrowLine
            ? _freeThrowEligible(local, size, point)
            : CourtGeometry.contains(region, point));
  }

  void _emitPoint(CourtPoint point, Offset local, Size size) {
    if (widget.onCourtSelectionTap != null) {
      widget.onCourtSelectionTap!(
        CourtSelection(
          point: point,
          freeThrowEligible: _freeThrowEligible(local, size, point),
        ),
      );
    } else {
      widget.onCourtPointTap?.call(point);
    }
  }

  void _handlePosition(Offset local, Size size) {
    if (widget.mode == CourtViewMode.readOnly ||
        !HalfCourtGeometry.courtRectForSize(size).contains(local)) {
      return;
    }
    final point = pointFromLocal(local, size);
    if (!_accepts(point, local, size)) {
      widget.onInvalidCourtPoint?.call(point);
      return;
    }
    if (widget.pendingLocation != null) {
      widget.onPendingLocationChanged?.call(point);
    } else if (widget.detailedShotDraft != null) {
      _emitPoint(point, local, size);
    }
  }

  void _handleTap(Offset local, Size size) {
    if (widget.mode == CourtViewMode.readOnly ||
        !HalfCourtGeometry.courtRectForSize(size).contains(local)) {
      return;
    }
    final point = pointFromLocal(local, size);
    if (!_accepts(point, local, size)) {
      widget.onInvalidCourtPoint?.call(point);
      return;
    }
    if (widget.pendingLocation != null && widget.locationPrompt == null) {
      _handlePosition(local, size);
      return;
    }
    // A live capture owns coordinates, including coordinates under old marks.
    if (widget.activeRegion != null ||
        widget.pendingLocation != null ||
        widget.detailedShotDraft != null) {
      _emitPoint(point, local, size);
      return;
    }
    ScoringShotLocation? closest;
    var distanceLimit = 28.0;
    if (widget.onShotLocationTap != null) {
      for (final location in widget.shotLocations) {
        if (widget.hiddenShotLocationIds.contains(location.id)) continue;
        final center = HalfCourtGeometry.pointToOffset(location.point, size);
        final distance = (center - local).distance;
        if (distance <= distanceLimit) {
          closest = location;
          distanceLimit = distance;
        }
      }
    }
    if (closest != null) {
      widget.onShotLocationTap!(closest.id);
    } else {
      _emitPoint(point, local, size);
    }
  }

  CourtPoint _initialCursor() =>
      widget.detailedShotDraft?.point ??
      widget.pendingLocation?.point ??
      switch (widget.activeRegion) {
        CourtRegion.outsideArc => CourtPoint(x: .5, y: .8),
        CourtRegion.freeThrowLine => CourtGeometry.freeThrowPoint,
        _ => CourtPoint(x: .5, y: .5),
      };

  void _moveCursor(double dx, double dy) {
    final cursor = _cursor ?? _initialCursor();
    setState(
      () => _cursor = CourtPoint(
        x: (cursor.x + dx).clamp(0, 1),
        y: (cursor.y + dy).clamp(0, 1),
      ),
    );
  }

  void _confirmCursor(Size size) {
    final cursor = _cursor;
    // The first activation reveals the candidate. Confirmation is explicit.
    if (cursor == null) {
      setState(() => _cursor = _initialCursor());
      return;
    }
    _handleTap(HalfCourtGeometry.pointToOffset(cursor, size), size);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
      final editorial = editorialThemeOf(context);
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final editable = widget.mode == CourtViewMode.editable;
      final regionHint = switch (widget.activeRegion) {
        CourtRegion.insideArc => l10n.courtRegionInsideHint,
        CourtRegion.outsideArc => l10n.courtRegionOutsideHint,
        CourtRegion.all => l10n.courtRegionAllHint,
        CourtRegion.freeThrowLine => l10n.courtRegionFreeThrowHint,
        null => l10n.courtEditHint,
      };
      return FocusableActionDetector(
        key: const Key('court-keyboard-target'),
        focusNode: _focus,
        enabled: editable,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveCourtCursorIntent(
            -.05,
            0,
          ),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              _MoveCourtCursorIntent(.05, 0),
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoveCourtCursorIntent(
            0,
            -.05,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown): _MoveCourtCursorIntent(
            0,
            .05,
          ),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          _MoveCourtCursorIntent: CallbackAction<_MoveCourtCursorIntent>(
            onInvoke: (intent) {
              _moveCursor(intent.dx, intent.dy);
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _confirmCursor(size);
              return null;
            },
          ),
        },
        child: Semantics(
          container: true,
          onTap: editable ? () => _confirmCursor(size) : null,
          onTapHint: editable ? l10n.courtConfirmPoint : null,
          label: editable ? l10n.courtEditLabel : l10n.courtReplayLabel,
          hint: editable ? regionHint : l10n.courtReplayHint,
          value: _cursor == null
              ? null
              : '${(_cursor!.x * 100).round()}%, ${(_cursor!.y * 100).round()}%',
          customSemanticsActions: !editable
              ? null
              : {
                  CustomSemanticsAction(label: l10n.courtMoveLeft): () =>
                      _moveCursor(-.05, 0),
                  CustomSemanticsAction(label: l10n.courtMoveRight): () =>
                      _moveCursor(.05, 0),
                  CustomSemanticsAction(label: l10n.courtMoveUp): () =>
                      _moveCursor(0, -.05),
                  CustomSemanticsAction(label: l10n.courtMoveDown): () =>
                      _moveCursor(0, .05),
                  CustomSemanticsAction(label: l10n.courtConfirmPoint): () =>
                      _confirmCursor(size),
                },
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                onTapDown: editable
                    ? (details) => _handleTap(details.localPosition, size)
                    : null,
                onPanUpdate: editable
                    ? (details) => _handlePosition(details.localPosition, size)
                    : null,
                child: CustomPaint(
                  key: widget.geometryKey,
                  painter: CourtPainter(
                    shotLocations: widget.shotLocations,
                    pendingLocation: widget.pendingLocation,
                    detailedShotDraft: widget.detailedShotDraft,
                    highlightedShotLocationId: widget.highlightedShotLocationId,
                    hiddenShotLocationIds: widget.hiddenShotLocationIds,
                    transientMarkers: widget.transientMarkers,
                    eraserMarkers: widget.eraserMarkers,
                    freeThrowMarkers: widget.freeThrowMarkers,
                    activeRegion: widget.activeRegion,
                    regionPulse: _pulse,
                    accessibleCursor: _cursor,
                    highlightFreeThrowLine: widget.highlightFreeThrowLine,
                    surfaceColor: editorial.surface,
                    lineColor: editorial.ink,
                    accentColor: editorial.arenaAccent,
                    eraserColor: editorial.ink,
                    teamBlueColor: editorial.teamBlue,
                    teamRedColor: editorial.teamRed,
                    markerRingColor: editorial.ink,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              if (widget.locationPrompt != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Semantics(
                        liveRegion: true,
                        label: widget.locationPrompt,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: .94),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Flexible(child: Text(widget.locationPrompt!)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _MoveCourtCursorIntent extends Intent {
  const _MoveCourtCursorIntent(this.dx, this.dy);
  final double dx;
  final double dy;
}
