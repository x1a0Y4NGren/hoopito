import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/features/practice/practice_coach_layout.dart';

void main() {
  test('pointer takes an unobstructed detour around a protected control', () {
    const bubble = Rect.fromLTWH(20, 110, 100, 60);
    const target = Rect.fromLTWH(300, 110, 48, 48);
    const control = Rect.fromLTWH(180, 100, 60, 80);
    final route = practicePointerRoute(bubble, target, [
      control,
    ], const Rect.fromLTWH(0, 0, 400, 300));
    expect(route.length, greaterThan(2));
    for (var i = 1; i < route.length; i++) {
      for (var sample = 1; sample < 100; sample++) {
        expect(
          control.contains(Offset.lerp(route[i - 1], route[i], sample / 100)!),
          isFalse,
        );
      }
    }
    expect(
      (route.first - practiceNearestPoint(bubble, route.first)).distance,
      lessThan(.01),
    );
    expect(
      (route.last - practiceNearestPoint(target, route.last)).distance,
      lessThan(.01),
    );
  });

  test('unblocked pointer keeps the shortest direct segment', () {
    const bubble = Rect.fromLTWH(20, 110, 100, 60);
    const target = Rect.fromLTWH(300, 110, 48, 48);
    final route = practicePointerRoute(
      bubble,
      target,
      [],
      const Rect.fromLTWH(0, 0, 400, 300),
    );
    expect(route.length, 2);
  });
}
