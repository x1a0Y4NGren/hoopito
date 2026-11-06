import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/features/practice/practice_coach_layout.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';

enum PracticeTargetId {
  start,
  blueTwo,
  undo,
  court,
  redTwo,
  blueMiss,
  finish,
  summaryScore,
  finishControls,
  finishConfirm,
}

typedef PracticeRectBuilder = Rect Function(Size size);

class PracticeCoachHost extends StatefulWidget {
  const PracticeCoachHost({
    required this.presentation,
    required this.child,
    this.target,
    this.hint,
    this.enabled = true,
    super.key,
  });
  final PracticePresentation presentation;
  final Widget child;
  final PracticeTargetId? target;
  final String? hint;
  final bool enabled;

  @override
  State<PracticeCoachHost> createState() => _PracticeCoachHostState();
}

class _PracticeCoachHostState extends State<PracticeCoachHost>
    with WidgetsBindingObserver {
  final _surface = GlobalKey();
  final _anchors = <_PracticeAnchorState>{};
  Rect? _targetRect;
  Offset _globalOffset = Offset.zero;
  List<Rect> _avoids = [];
  bool _scheduled = false;
  bool _expanded = false;
  PracticeTargetId? _revealed;

  PracticeTargetId get _target =>
      widget.target ??
      switch (widget.presentation.step) {
        PracticeStep.pregame => PracticeTargetId.start,
        PracticeStep.scoreBlueTwo => PracticeTargetId.blueTwo,
        PracticeStep.undo => PracticeTargetId.undo,
        PracticeStep.courtPoint => PracticeTargetId.court,
        PracticeStep.scoreRedTwo => PracticeTargetId.redTwo,
        PracticeStep.missBlue => PracticeTargetId.blueMiss,
        PracticeStep.finish => PracticeTargetId.finish,
        PracticeStep.result => PracticeTargetId.summaryScore,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() => _schedule();
  @override
  void didUpdateWidget(covariant PracticeCoachHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentation.step != widget.presentation.step ||
        oldWidget.target != widget.target ||
        oldWidget.hint != widget.hint) {
      _expanded = false;
      _revealed = null;
    }
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _schedule() {
    if (_scheduled || !mounted) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        _measure();
      }
    });
  }

  Rect? _rect(_PracticeAnchorState anchor, RenderBox surface) {
    final box = anchor.context.findRenderObject();
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        box.size.isEmpty) {
      return null;
    }
    final local =
        anchor.widget.rectBuilder?.call(box.size) ?? Offset.zero & box.size;
    var rect = MatrixUtils.transformRect(box.getTransformTo(surface), local);
    if (!rect.isFinite || rect.isEmpty) {
      return null;
    }
    RenderObject? parent = box.parent;
    while (parent != null && parent != surface) {
      if (parent is RenderOffstage && parent.offstage) {
        return null;
      }
      if (parent is RenderAbstractViewport && parent is RenderBox) {
        final viewportBox = parent as RenderBox;
        if (!viewportBox.hasSize) {
          return null;
        }
        final clip = MatrixUtils.transformRect(
          viewportBox.getTransformTo(surface),
          Offset.zero & viewportBox.size,
        );
        if (anchor.widget.avoid) {
          rect = rect.intersect(clip);
          if (rect.isEmpty) {
            return null;
          }
        } else if (!_containsRect(clip, rect)) {
          return null;
        }
      }
      parent = parent.parent;
    }
    final media = MediaQuery.of(context);
    final global = surface.localToGlobal(Offset.zero);
    final safe = Rect.fromLTRB(
      math.max(0, media.padding.left - global.dx),
      math.max(0, media.padding.top - global.dy),
      math.min(
        surface.size.width,
        media.size.width - media.padding.right - global.dx,
      ),
      math.min(
        surface.size.height,
        media.size.height -
            math.max(media.viewInsets.bottom, media.padding.bottom) -
            global.dy,
      ),
    );
    if (anchor.widget.avoid) {
      return rect.overlaps(safe) ? rect.intersect(safe) : null;
    }
    if (!_containsRect(safe, rect)) {
      return null;
    }
    return rect;
  }

  void _measure() {
    final surface = _surface.currentContext?.findRenderObject();
    if (surface is! RenderBox || !surface.hasSize || !surface.attached) {
      return;
    }
    // Ancestor transforms (including popup transitions) are safe to read only
    // after layout. The overlay consumes this cached origin during its layout.
    final globalOffset = surface.localToGlobal(Offset.zero);
    Rect? target;
    final avoids = <Rect>[];
    for (final anchor in _anchors.toList()) {
      if (!anchor.mounted) {
        continue;
      }
      final w = anchor.widget;
      if (w.avoid && w.active) {
        final r = _rect(anchor, surface);
        if (r != null) {
          avoids.add(r);
        }
      } else if (w.active && w.id == _target) {
        target = _rect(anchor, surface);
        if (_revealed != _target &&
            widget.enabled &&
            widget.presentation.showCoach &&
            ModalRoute.of(context)?.isCurrent != false) {
          _revealed = _target;
          if (target == null) {
            Scrollable.ensureVisible(anchor.context, alignment: .5);
          }
        }
        target = _rect(anchor, surface);
      }
    }
    if (_targetRect != target ||
        !_sameRects(_avoids, avoids) ||
        _globalOffset != globalOffset) {
      setState(() {
        _targetRect = target;
        _avoids = avoids;
        _globalOffset = globalOffset;
      });
    }
  }

  bool _sameRects(List<Rect> a, List<Rect> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);

  @override
  Widget build(BuildContext context) {
    // Route dependency also hides a page's guidance while its dialog is open.
    final visible =
        widget.enabled &&
        widget.presentation.showCoach &&
        ModalRoute.of(context)?.isCurrent != false;
    _schedule();
    return _PracticeRegistry(
      host: this,
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _schedule();
          return false;
        },
        child: Stack(
          key: _surface,
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (visible)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      _overlay(context, constraints.biggest),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context, Size size) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsZh();
    final hint = widget.hint ?? _hint(l10n, widget.presentation.step);
    final media = MediaQuery.of(context);
    final offset = _globalOffset;
    final viewport = Rect.fromLTRB(
      math.max(8, media.padding.left - offset.dx + 8),
      math.max(8, media.padding.top - offset.dy + 8),
      math.min(
        size.width - 8,
        media.size.width - media.padding.right - offset.dx - 8,
      ),
      math.min(
        size.height - 8,
        media.size.height -
            math.max(media.viewInsets.bottom, media.padding.bottom) -
            offset.dy -
            8,
      ),
    );
    if (viewport.width < 48 || viewport.height < 48) {
      return const SizedBox();
    }
    final target = _targetRect;
    final obstacles = [..._avoids, ?target];
    final regions = practiceOpenRegions(viewport, obstacles);
    final style = Theme.of(context).textTheme.bodyMedium!;
    final badgeStyle = Theme.of(context).textTheme.labelLarge!;
    final progress = l10n.practiceStepProgress(
      widget.presentation.step.number,
      7,
    );
    double textHeight(String text, TextStyle style, double width) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: media.textScaler,
      )..layout(maxWidth: math.max(1, width));
      return painter.height;
    }

    final anchor = target?.center ?? viewport.center;
    Rect? placement;
    var compact = false;
    double best = double.infinity;
    final heading = '${l10n.practiceBadge} · $progress';
    // Prefer a comfortable reading width, then try a wide shallow region or a
    // tall side lane. 96dp leaves 48dp for exit, 24dp for padding and a wrapping
    // title. All text is measured at the user's actual font scale.
    for (final (minimumWidth, maximumWidth) in [
      (190.0, 320.0),
      (190.0, double.infinity),
      (96.0, 320.0),
    ]) {
      for (final region in regions) {
        final width = math.min(maximumWidth, region.width);
        if (width < minimumWidth) {
          continue;
        }
        final height = width >= 190
            ? 24.0 +
                  math.max(
                    48.0,
                    textHeight(heading, badgeStyle, width - 80) +
                        8 +
                        textHeight(hint, style, width - 80),
                  )
            : 24.0 +
                  math.max(
                    48.0,
                    textHeight(l10n.practiceBadge, badgeStyle, width - 80),
                  ) +
                  textHeight(progress, badgeStyle, width - 24) +
                  8 +
                  textHeight(hint, style, width - 24);
        if (height > region.height) {
          continue;
        }
        final rect = practicePlaceInRegion(region, Size(width, height), anchor);
        final cost = target == null
            ? (rect.center - anchor).distance
            : _pointerCost(rect, target, obstacles);
        if (cost < best) {
          best = cost;
          placement = rect;
        }
      }
      if (placement != null) break;
    }
    if (placement == null) {
      compact = true;
      for (final region in regions) {
        final width = math.min(280.0, region.width);
        final compactHeight = width < 128 ? 152.0 : 64.0;
        if (width < 64 || region.height < compactHeight) {
          continue;
        }
        final rect = practicePlaceInRegion(
          region,
          Size(width, compactHeight),
          anchor,
        );
        final cost = target == null
            ? (rect.center - anchor).distance
            : _pointerCost(rect, target, obstacles);
        if (cost < best) {
          best = cost;
          placement = rect;
        }
      }
    }
    // On an exceptionally crowded viewport retain explicit collapse and exit
    // controls in a panel; its Material consumes taps rather than leaking them.
    placement ??= Rect.fromLTWH(
      viewport.left,
      viewport.top,
      math.min(320, viewport.width),
      math.min(viewport.width < 128 ? 152 : 64, viewport.height),
    );
    final expanded = compact && _expanded;
    final bubble = expanded
        ? Rect.fromLTWH(
            viewport.left,
            viewport.top,
            viewport.width,
            math.min(viewport.height, 260),
          )
        : placement;
    return Stack(
      children: [
        if (target != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(
                  key: const Key('practice-coach-mask'),
                  painter: _SpotlightPainter(
                    target,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        if (target != null && !bubble.overlaps(target))
          _arrow(
            bubble,
            target,
            viewport,
            Theme.of(context).colorScheme.primary,
          ),
        Positioned.fromRect(
          rect: bubble,
          child: Material(
            key: const Key('practice-coach'),
            elevation: 5,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Semantics(
              container: true,
              child: Padding(
                padding: EdgeInsets.all(
                  compact && bubble.width < 128
                      ? 4
                      : (compact && !expanded ? 8 : 12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (expanded) ...[
                      SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _hintToggle(l10n, expanded: true),
                            _exit(l10n),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.practiceBadge, style: badgeStyle),
                              Text(progress, style: badgeStyle),
                              const SizedBox(height: 8),
                              Text(
                                hint,
                                key: const Key('practice-coach-hint'),
                                style: style,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (compact &&
                        bubble.width < 128 &&
                        bubble.height < 144) ...[
                      // A short keyboard viewport has room for both controls
                      // side by side; fixed text must not displace either one.
                      SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _hintToggle(l10n, expanded: false),
                            _exit(l10n),
                          ],
                        ),
                      ),
                    ] else if (compact && bubble.width < 128) ...[
                      SizedBox(
                        height: 24,
                        child: Text(
                          '$progress · ${l10n.practiceBadge}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: badgeStyle,
                        ),
                      ),
                      IconButton(
                        key: const Key('practice-coach-toggle'),
                        tooltip: expanded
                            ? l10n.practiceHideHint
                            : l10n.practiceShowHint,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        onPressed: () => setState(() => _expanded = !expanded),
                        icon: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                        ),
                      ),
                      _exit(l10n),
                      if (expanded)
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              hint,
                              key: const Key('practice-coach-hint'),
                              style: style,
                            ),
                          ),
                        ),
                    ] else if (compact && !expanded)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$progress · ${l10n.practiceBadge}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: badgeStyle,
                              ),
                            ),
                            IconButton(
                              key: const Key('practice-coach-toggle'),
                              tooltip: l10n.practiceShowHint,
                              constraints: const BoxConstraints.tightFor(
                                width: 48,
                                height: 48,
                              ),
                              onPressed: () => setState(() => _expanded = true),
                              icon: const Icon(Icons.expand_more),
                            ),
                            _exit(l10n),
                          ],
                        ),
                      )
                    else if (bubble.width >= 190)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(heading, style: badgeStyle),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Text(
                                        hint,
                                        key: const Key('practice-coach-hint'),
                                        style: style,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _exit(l10n),
                          ],
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(l10n.practiceBadge, style: badgeStyle),
                          ),
                          if (expanded)
                            IconButton(
                              key: const Key('practice-coach-toggle'),
                              tooltip: l10n.practiceHideHint,
                              constraints: const BoxConstraints.tightFor(
                                width: 48,
                                height: 48,
                              ),
                              onPressed: () =>
                                  setState(() => _expanded = false),
                              icon: const Icon(Icons.expand_less),
                            ),
                          _exit(l10n),
                        ],
                      ),
                      Text(progress, style: badgeStyle),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            hint,
                            key: const Key('practice-coach-hint'),
                            style: style,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        // Stable node and label: geometry-only rebuilds do not announce again.
        Positioned(
          left: 0,
          top: 0,
          child: Semantics(
            key: ValueKey(
              'practice-announcement-${widget.presentation.step}-${widget.target}-$hint',
            ),
            liveRegion: true,
            label: '$progress · $hint',
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _hintToggle(AppLocalizations l10n, {required bool expanded}) =>
      IconButton(
        key: const Key('practice-coach-toggle'),
        tooltip: expanded ? l10n.practiceHideHint : l10n.practiceShowHint,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        onPressed: () => setState(() => _expanded = !expanded),
        icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
      );

  Widget _exit(AppLocalizations l10n) => IconButton(
    key: const Key('practice-exit'),
    tooltip: l10n.practiceExit,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    onPressed: widget.presentation.onExit,
    icon: const Icon(Icons.close),
  );

  double _pointerCost(Rect bubble, Rect target, List<Rect> obstacles) {
    final start = practiceNearestPoint(bubble, target.center);
    final end = practiceNearestPoint(target, start);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    // Penalize an obstructed pointer; prefer the shortest clear route.
    final blocked = obstacles
        .where((r) => r != target)
        .any((r) => _lineCrosses(start, end, r));
    return practicePointerDistance(bubble, target) +
        (blocked ? 10000 : 0) +
        path.getBounds().width * .001;
  }

  Widget _arrow(Rect bubble, Rect target, Rect viewport, Color color) {
    final route = practicePointerRoute(bubble, target, _avoids, viewport);
    if (route.length < 2) {
      return const SizedBox.shrink();
    }
    var bounds = Rect.fromPoints(route.first, route.last);
    for (final point in route) {
      bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
    }
    final rect = bounds.inflate(7);
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(
            key: const Key('practice-coach-arrow'),
            painter: _ArrowPainter(
              route.map((p) => p - rect.topLeft).toList(),
              color,
            ),
          ),
        ),
      ),
    );
  }
}

bool _containsRect(Rect outer, Rect inner) =>
    inner.left >= outer.left - .01 &&
    inner.top >= outer.top - .01 &&
    inner.right <= outer.right + .01 &&
    inner.bottom <= outer.bottom + .01;

bool _lineCrosses(Offset a, Offset b, Rect rect) {
  for (var i = 1; i < 20; i++) {
    if (rect.contains(Offset.lerp(a, b, i / 20)!)) {
      return true;
    }
  }
  return false;
}

String _hint(AppLocalizations l10n, PracticeStep step) => switch (step) {
  PracticeStep.pregame => l10n.practiceSetupHint,
  PracticeStep.scoreBlueTwo => l10n.practiceScoreHint,
  PracticeStep.undo => l10n.practiceUndoHint,
  PracticeStep.courtPoint => l10n.practiceCourtHint,
  PracticeStep.scoreRedTwo => l10n.practiceLocatedScoreHint,
  PracticeStep.missBlue => l10n.practiceMissHint,
  PracticeStep.finish => l10n.practiceFinishHint,
  PracticeStep.result => l10n.practiceResultHint,
};

class PracticeTarget extends StatelessWidget {
  const PracticeTarget({
    required this.active,
    required this.child,
    this.id,
    this.rectBuilder,
    super.key,
  });
  final bool active;
  final Widget child;
  final PracticeTargetId? id;
  final PracticeRectBuilder? rectBuilder;
  @override
  Widget build(BuildContext context) => _PracticeAnchor(
    active: active,
    id: id,
    rectBuilder: rectBuilder,
    child: child,
  );
}

class PracticeAvoid extends StatelessWidget {
  const PracticeAvoid({
    required this.child,
    this.enabled = true,
    this.rectBuilder,
    super.key,
  });
  final Widget child;
  final bool enabled;
  final PracticeRectBuilder? rectBuilder;
  @override
  Widget build(BuildContext context) => _PracticeAnchor(
    active: enabled,
    avoid: true,
    rectBuilder: rectBuilder,
    child: child,
  );
}

class _PracticeRegistry extends InheritedWidget {
  const _PracticeRegistry({required this.host, required super.child});
  final _PracticeCoachHostState host;
  @override
  bool updateShouldNotify(_PracticeRegistry oldWidget) =>
      oldWidget.host != host;
}

class _PracticeAnchor extends StatefulWidget {
  const _PracticeAnchor({
    required this.active,
    required this.child,
    this.id,
    this.rectBuilder,
    this.avoid = false,
  });
  final bool active;
  final Widget child;
  final PracticeTargetId? id;
  final PracticeRectBuilder? rectBuilder;
  final bool avoid;
  @override
  State<_PracticeAnchor> createState() => _PracticeAnchorState();
}

class _PracticeAnchorState extends State<_PracticeAnchor> {
  _PracticeCoachHostState? _host;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = context
        .dependOnInheritedWidgetOfExactType<_PracticeRegistry>()
        ?.host;
    if (_host != host) {
      _host?._anchors.remove(this);
      _host?._schedule();
      _host = host;
      host?._anchors.add(this);
    }
    host?._schedule();
  }

  @override
  void didUpdateWidget(covariant _PracticeAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _host?._schedule();
  }

  @override
  void deactivate() {
    _host?._anchors.remove(this);
    _host?._schedule();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _host?._anchors.add(this);
    _host?._schedule();
  }

  @override
  void dispose() {
    _host?._anchors.remove(this);
    _host?._schedule();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _GeometryObserver(onPaint: () => _host?._schedule(), child: widget.child);
}

/// RenderProxyBox contributes no layout constraints or decoration padding.
class _GeometryObserver extends SingleChildRenderObjectWidget {
  const _GeometryObserver({required this.onPaint, required super.child});
  final VoidCallback onPaint;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GeometryRenderBox(onPaint);
  @override
  void updateRenderObject(
    BuildContext context,
    _GeometryRenderBox renderObject,
  ) {
    renderObject.onPaint = onPaint;
  }
}

class _GeometryRenderBox extends RenderProxyBox {
  _GeometryRenderBox(this.onPaint);
  VoidCallback onPaint;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint();
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.target, this.color);
  final Rect target;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      target.inflate(3),
      const Radius.circular(8),
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: .18));
    canvas.drawRRect(
      hole,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      target != oldDelegate.target || color != oldDelegate.color;
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.points, this.color);
  final List<Offset> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final to = points.last;
    final delta = to - points[points.length - 2];
    if (delta.distance < 1) {
      return;
    }
    final unit = delta / delta.distance;
    final normal = Offset(-unit.dy, unit.dx);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(line, paint);
    canvas.drawPath(
      Path()
        ..moveTo(
          (to - unit * 7 + normal * 4).dx,
          (to - unit * 7 + normal * 4).dy,
        )
        ..lineTo(to.dx, to.dy)
        ..lineTo(
          (to - unit * 7 - normal * 4).dx,
          (to - unit * 7 - normal * 4).dy,
        ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      color != oldDelegate.color ||
      points.length != oldDelegate.points.length ||
      List.generate(
        points.length,
        (i) => points[i] != oldDelegate.points[i],
      ).any((changed) => changed);
}
