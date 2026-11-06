import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Searches all open rectangles formed by obstacle edges, including corners
/// and narrow side lanes rather than only centered placements.
List<Rect> practiceOpenRegions(Rect viewport, List<Rect> obstacles) {
  final blocked = obstacles
      .where((r) => r.overlaps(viewport))
      .map((r) => r.inflate(8).intersect(viewport))
      .toList();
  final xs = <double>{
    viewport.left,
    viewport.right,
    for (final r in blocked) ...[r.left, r.right],
  }.toList()..sort();
  final ys = <double>{
    viewport.top,
    viewport.bottom,
    for (final r in blocked) ...[r.top, r.bottom],
  }.toList()..sort();
  final regions = <Rect>[];
  for (var a = 0; a < xs.length - 1; a++) {
    for (var b = a + 1; b < xs.length; b++) {
      for (var c = 0; c < ys.length - 1; c++) {
        for (var d = c + 1; d < ys.length; d++) {
          final r = Rect.fromLTRB(xs[a], ys[c], xs[b], ys[d]);
          if (!blocked.any(r.overlaps)) {
            regions.add(r);
          }
        }
      }
    }
  }
  return regions;
}

Offset practiceNearestPoint(Rect rect, Offset point) => Offset(
  point.dx.clamp(rect.left, rect.right),
  point.dy.clamp(rect.top, rect.bottom),
);

double practicePointerDistance(Rect bubble, Rect target) {
  final start = practiceNearestPoint(bubble, target.center);
  final end = practiceNearestPoint(target, start);
  return (end - start).distance;
}

Rect practicePlaceInRegion(Rect region, Size size, Offset anchor) {
  final x = (anchor.dx - size.width / 2).clamp(
    region.left,
    math.max(region.left, region.right - size.width),
  );
  final y = (anchor.dy - size.height / 2).clamp(
    region.top,
    math.max(region.top, region.bottom - size.height),
  );
  return Rect.fromLTWH(x.toDouble(), y.toDouble(), size.width, size.height);
}

/// Routes only the final pointer. A bounded visibility graph connects bubble
/// and target edges around protected rectangle corners inside the viewport.
/// An empty path is safer than drawing through a control when no route exists.
List<Offset> practicePointerRoute(
  Rect bubble,
  Rect target,
  List<Rect> avoids,
  Rect viewport,
) {
  List<Offset> edges(Rect rect, Offset toward) => [
    practiceNearestPoint(rect, toward),
    rect.topCenter,
    rect.centerRight,
    rect.bottomCenter,
    rect.centerLeft,
  ];
  final starts = edges(bubble, target.center).toSet().toList();
  final ends = edges(target, bubble.center).toSet().toList();
  final protected = avoids
      .where((r) => !r.isEmpty)
      .map((r) => r.inflate(4))
      .toList();
  final blocked = [
    bubble.deflate(.01),
    target.deflate(.01),
    ...protected.map((r) => r.deflate(.01)),
  ];
  bool within(Offset p) =>
      p.dx >= viewport.left &&
      p.dx <= viewport.right &&
      p.dy >= viewport.top &&
      p.dy <= viewport.bottom;
  final nodes = <Offset>[
    ...starts,
    ...ends,
    for (final rect in protected)
      for (final point in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ])
        if (within(point)) point,
  ];
  final distances = List<double>.filled(nodes.length, double.infinity);
  final previous = List<int>.filled(nodes.length, -1);
  final visited = List<bool>.filled(nodes.length, false);
  for (var i = 0; i < starts.length; i++) {
    if (within(nodes[i]) && !protected.any((r) => r.contains(nodes[i]))) {
      distances[i] = 0;
    }
  }
  for (var iteration = 0; iteration < nodes.length; iteration++) {
    var current = -1;
    for (var i = 0; i < nodes.length; i++) {
      if (!visited[i] && (current < 0 || distances[i] < distances[current])) {
        current = i;
      }
    }
    if (current < 0 || !distances[current].isFinite) {
      break;
    }
    if (current >= starts.length && current < starts.length + ends.length) {
      final path = <Offset>[];
      for (var i = current; i >= 0; i = previous[i]) {
        path.add(nodes[i]);
      }
      return path.reversed.toList();
    }
    visited[current] = true;
    for (var next = starts.length; next < nodes.length; next++) {
      if (visited[next] ||
          !within(nodes[next]) ||
          blocked.any(
            (r) => _pointerCrossesRect(nodes[current], nodes[next], r),
          )) {
        continue;
      }
      final distance =
          distances[current] + (nodes[next] - nodes[current]).distance;
      if (distance < distances[next]) {
        distances[next] = distance;
        previous[next] = current;
      }
    }
  }
  return [];
}

/// Slab intersection avoids sampling gaps on thin or distant obstacles.
bool _pointerCrossesRect(Offset a, Offset b, Rect rect) {
  var lower = 0.0;
  var upper = 1.0;
  for (final axis in [
    (a.dx, b.dx - a.dx, rect.left, rect.right),
    (a.dy, b.dy - a.dy, rect.top, rect.bottom),
  ]) {
    if (axis.$2.abs() < .00001) {
      if (axis.$1 <= axis.$3 || axis.$1 >= axis.$4) {
        return false;
      }
    } else {
      final first = (axis.$3 - axis.$1) / axis.$2;
      final second = (axis.$4 - axis.$1) / axis.$2;
      lower = math.max(lower, math.min(first, second));
      upper = math.min(upper, math.max(first, second));
      if (lower >= upper) {
        return false;
      }
    }
  }
  return upper > .00001 && lower < .99999;
}
