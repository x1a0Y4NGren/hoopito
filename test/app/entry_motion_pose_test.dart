import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/entry/entry_motion_pose.dart';

void main() {
  test(
    'approved bounce has anticipation, flight, landing and small rebound',
    () {
      final anticipation = EntryMotionPose.sample(0.15);
      expect(anticipation.offsetY, 1.5);
      expect(anticipation.scaleX, 1.08);
      expect(anticipation.scaleY, 0.92);
      expect(
        anticipation.rotationRadians,
        closeTo(-1.2 * math.pi / 180, 1e-12),
      );

      final flight = EntryMotionPose.sample(0.33);
      expect(flight.offsetY, -12);
      expect(flight.scaleX, 0.95);
      expect(flight.scaleY, 1.06);
      expect(flight.rotationRadians, closeTo(1.5 * math.pi / 180, 1e-12));

      final landing = EntryMotionPose.sample(0.48);
      expect(landing.offsetY, 1.5);
      expect(landing.scaleX, 1.10);
      expect(landing.scaleY, 0.91);
      expect(EntryMotionPose.sample(0.55).offsetY, -3);
      expect(EntryMotionPose.sample(0.62).offsetY, 0);
    },
  );

  test('start, settled ending and zero motion strength are exact original', () {
    for (final t in [0.0, 0.03, 0.06, 0.76, 0.8, 0.95, 1.0]) {
      expect(EntryMotionPose.sample(t).isRest, isTrue, reason: 't=$t');
    }
    for (var ms = 0; ms <= 1000; ms++) {
      expect(
        EntryMotionPose.sample(ms / 1000, motionStrength: 0).isRest,
        isTrue,
      );
    }
  });

  test(
    'skip strength scales the current pose continuously back to original',
    () {
      for (final t in [0.15, 0.25, 0.48, 0.55, 0.69]) {
        final full = EntryMotionPose.sample(t);
        final half = EntryMotionPose.sample(t, motionStrength: 0.5);
        expect(half.offsetY, full.offsetY / 2);
        expect(half.scaleX - 1, closeTo((full.scaleX - 1) / 2, 1e-12));
        expect(half.scaleY - 1, closeTo((full.scaleY - 1) / 2, 1e-12));
        expect(half.rotationRadians, full.rotationRadians / 2);
        expect(half.waveAmplitude, full.waveAmplitude / 2);
        expect(half.rippleAmplitude, full.rippleAmplitude / 2);
      }
    },
  );

  test(
    'body keyframes and wave envelopes have continuous first derivatives',
    () {
      const epsilon = 0.000001;
      for (final t in [0.06, 0.15, 0.2346, 0.33, 0.48, 0.55, 0.62, 0.76]) {
        final before = _components(EntryMotionPose.sample(t - epsilon));
        final at = _components(EntryMotionPose.sample(t));
        final after = _components(EntryMotionPose.sample(t + epsilon));
        for (var i = 0; i < at.length; i++) {
          final leftVelocity = (at[i] - before[i]) / epsilon;
          final rightVelocity = (after[i] - at[i]) / epsilon;
          expect(leftVelocity, closeTo(rightVelocity, 0.03), reason: '$t / $i');
        }
      }
    },
  );

  test('main wave is bounded and the final ripple lasts exactly 140ms', () {
    var largestMainWave = 0.0;
    var largestRipple = 0.0;
    for (var ms = 0; ms <= 1000; ms++) {
      final pose = EntryMotionPose.sample(ms / 1000);
      expect(pose.waveAmplitude, inInclusiveRange(0, 3));
      expect(pose.rippleAmplitude, inInclusiveRange(0, 2));
      if (ms <= 150 || ms >= 620) expect(pose.waveAmplitude, 0);
      if (ms <= 620 || ms >= 760) expect(pose.rippleAmplitude, 0);
      largestMainWave = math.max(largestMainWave, pose.waveAmplitude);
      largestRipple = math.max(largestRipple, pose.rippleAmplitude);
    }
    expect(largestMainWave, closeTo(3, 0.001));
    expect(largestRipple, closeTo(2, 0.001));
    expect(EntryMotionPose.sample(0.69).rippleProgress, closeTo(0.5, 1e-12));
  });

  test('second travelling wave is weaker than the first wave', () {
    var firstPeak = 0.0;
    var secondPeak = 0.0;
    for (var ms = 150; ms <= 620; ms++) {
      final amplitude = EntryMotionPose.sample(ms / 1000).waveAmplitude;
      if (ms < 385) {
        firstPeak = math.max(firstPeak, amplitude);
      } else {
        secondPeak = math.max(secondPeak, amplitude);
      }
    }
    expect(firstPeak, greaterThan(secondPeak * 1.4));
  });
}

List<double> _components(EntryMotionPose pose) => [
  pose.offsetY,
  pose.scaleX,
  pose.scaleY,
  pose.rotationRadians,
  pose.waveAmplitude,
  pose.rippleAmplitude,
];
