import 'dart:math' as math;

import 'package:hoopito/core/domain/value_objects/court_point.dart';

enum CourtRegion { all, insideArc, outsideArc, freeThrowLine }

/// Meter-based geometry shared by live input validation and court drawing.
class CourtGeometry {
  const CourtGeometry._();

  static const width = 15.0;
  static const depth = 14.0;
  static const centerX = width / 2;
  static const basketY = 1.575;
  static const threePointRadius = 6.75;
  static const cornerOffset = .9;
  static const freeThrowLineY = 5.8;
  static const freeThrowLineWidth = 3.6;

  static double get cornerJoinY =>
      basketY +
      math.sqrt(
        threePointRadius * threePointRadius -
            (centerX - cornerOffset) * (centerX - cornerOffset),
      );

  static CourtPoint get freeThrowPoint =>
      CourtPoint(x: .5, y: freeThrowLineY / depth);

  static bool isOutsideArc(CourtPoint point) {
    final x = point.x * width;
    final y = point.y * depth;
    // Keep floating-point error at the drawn boundary on the inside.
    const epsilon = 1e-9;
    if (y <= cornerJoinY) {
      return x < cornerOffset - epsilon || x > width - cornerOffset + epsilon;
    }
    final dx = x - centerX;
    final dy = y - basketY;
    return dx * dx + dy * dy > threePointRadius * threePointRadius + epsilon;
  }

  static bool contains(CourtRegion region, CourtPoint point) {
    if (!point.x.isFinite ||
        !point.y.isFinite ||
        point.x < 0 ||
        point.x > 1 ||
        point.y < 0 ||
        point.y > 1) {
      return false;
    }
    return switch (region) {
      CourtRegion.all => true,
      CourtRegion.insideArc => !isOutsideArc(point),
      CourtRegion.outsideArc => isOutsideArc(point),
      // Touch tolerance is applied by the view, never by durable FG validation.
      CourtRegion.freeThrowLine =>
        (point.y * depth - freeThrowLineY).abs() < 1e-9 &&
            (point.x * width - centerX).abs() <= freeThrowLineWidth / 2,
    };
  }
}
