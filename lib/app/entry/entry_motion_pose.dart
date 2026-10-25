import 'dart:math' as math;

/// Deterministic pose for the one-second entry animation.
class EntryMotionPose {
  const EntryMotionPose._({
    this.offsetY = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotationRadians = 0,
    this.waveProgress = 0,
    this.waveAmplitude = 0,
    this.rippleProgress = 0,
    this.rippleAmplitude = 0,
  });

  static const canvasExtent = 288.0;
  static const baseScale = 0.78;
  static const rest = EntryMotionPose._();

  static EntryMotionPose sample(double progress, {double motionStrength = 1}) {
    assert(progress.isFinite);
    assert(motionStrength.isFinite);
    final strength = motionStrength.clamp(0.0, 1.0);
    final ms = progress.clamp(0.0, 1.0) * 1000;
    if (strength == 0 || ms <= 60 || ms >= 760) return rest;

    final keyframes = _bodyKeyframes;
    var body = keyframes.last;
    for (var i = 1; i < keyframes.length; i++) {
      final end = keyframes[i];
      if (ms > end.milliseconds) continue;
      final begin = keyframes[i - 1];
      final t = _smoothStep(
        (ms - begin.milliseconds) / (end.milliseconds - begin.milliseconds),
      );
      body = _BodyKeyframe(
        milliseconds: ms,
        offsetY: _lerp(begin.offsetY, end.offsetY, t),
        scaleX: _lerp(begin.scaleX, end.scaleX, t),
        scaleY: _lerp(begin.scaleY, end.scaleY, t),
        degrees: _lerp(begin.degrees, end.degrees, t),
      );
      break;
    }

    final waveProgress = ((ms - 150) / 470).clamp(0.0, 1.0);
    final rippleProgress = ((ms - 620) / 140).clamp(0.0, 1.0);
    return EntryMotionPose._(
      offsetY: body.offsetY * strength,
      scaleX: 1 + (body.scaleX - 1) * strength,
      scaleY: 1 + (body.scaleY - 1) * strength,
      rotationRadians: body.degrees * math.pi / 180 * strength,
      waveProgress: waveProgress,
      waveAmplitude: 3 * _decayingEnvelope(waveProgress) * strength,
      rippleProgress: rippleProgress,
      rippleAmplitude: 2 * _envelope(rippleProgress) * strength,
    );
  }

  final double offsetY;
  final double scaleX;
  final double scaleY;
  final double rotationRadians;
  final double waveProgress;
  final double waveAmplitude;
  final double rippleProgress;
  final double rippleAmplitude;

  bool get isRest =>
      offsetY == 0 &&
      scaleX == 1 &&
      scaleY == 1 &&
      rotationRadians == 0 &&
      waveAmplitude == 0 &&
      rippleAmplitude == 0;
}

const _bodyKeyframes = [
  _BodyKeyframe(milliseconds: 60),
  _BodyKeyframe(
    milliseconds: 150,
    offsetY: 1.5,
    scaleX: 1.08,
    scaleY: 0.92,
    degrees: -1.2,
  ),
  _BodyKeyframe(
    milliseconds: 330,
    offsetY: -12,
    scaleX: 0.95,
    scaleY: 1.06,
    degrees: 1.5,
  ),
  _BodyKeyframe(
    milliseconds: 480,
    offsetY: 1.5,
    scaleX: 1.10,
    scaleY: 0.91,
    degrees: -0.4,
  ),
  _BodyKeyframe(milliseconds: 550, offsetY: -3),
  _BodyKeyframe(milliseconds: 620),
];

class _BodyKeyframe {
  const _BodyKeyframe({
    required this.milliseconds,
    this.offsetY = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.degrees = 0,
  });

  final double milliseconds;
  final double offsetY;
  final double scaleX;
  final double scaleY;
  final double degrees;
}

double _envelope(double t) {
  if (t <= 0 || t >= 1) return 0;
  final sine = math.sin(math.pi * t);
  return sine * sine;
}

double _decayingEnvelope(double t) {
  if (t <= 0 || t >= 1) return 0;
  // A short C1 attack gives the first wave its energy, followed by a smooth
  // decay so the second pass is visibly smaller before the separate ripple.
  const attack = 0.18;
  if (t < attack) return _smoothStep(t / attack);
  return 1 - _smoothStep((t - attack) / (1 - attack));
}

double _smoothStep(double t) => t * t * (3 - 2 * t);

double _lerp(double begin, double end, double t) => begin + (end - begin) * t;
