import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:hoopito/app/entry/entry_motion_pose.dart';

typedef EntryVerticesBuilder =
    ui.Vertices Function(
      Float32List positions,
      Float32List textureCoordinates,
      Uint16List indices,
    );

/// Deforms the approved foreground texture without adding a second image layer.
/// The caller owns [image] and must keep it alive while this widget is mounted.
class EntryCreature extends StatefulWidget {
  const EntryCreature({
    required this.image,
    required this.progress,
    this.motionStrength = 1,
    this.verticesBuilder,
    this.onFallback,
    super.key,
  });

  final ui.Image image;
  final double progress;
  final double motionStrength;
  final VoidCallback? onFallback;

  /// Allows a test to reproduce a graphics backend allocation failure.
  @visibleForTesting
  final EntryVerticesBuilder? verticesBuilder;

  @override
  State<EntryCreature> createState() => _EntryCreatureState();
}

class _EntryCreatureState extends State<EntryCreature> {
  EntryCreatureMesh? _mesh;
  ui.ImageShader? _shader;
  bool _meshFailed = false;
  final _positions = Float32List(EntryCreatureMesh.vertexCount * 2);
  final _meshPaint = Paint();

  @override
  void initState() {
    super.initState();
    _prepareTexture();
  }

  void _prepareTexture() {
    _mesh = null;
    _shader = null;
    _meshFailed = false;
    try {
      _mesh = EntryCreatureMesh(
        imageWidth: widget.image.width,
        imageHeight: widget.image.height,
      );
      _shader = ui.ImageShader(
        widget.image,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
        filterQuality: ui.FilterQuality.high,
      );
      _meshPaint.shader = _shader;
    } on Object {
      // A renderer without mesh support must still show the original bitmap.
      _meshFailed = true;
      widget.onFallback?.call();
    }
  }

  @override
  void didUpdateWidget(covariant EntryCreature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image == widget.image) return;
    _shader?.dispose();
    _prepareTexture();
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: EntryMotionPose.canvasExtent,
    child: CustomPaint(
      painter: _EntryCreaturePainter(
        image: widget.image,
        drawMesh: _drawMesh,
        pose: EntryMotionPose.sample(
          widget.progress,
          motionStrength: widget.motionStrength,
        ),
      ),
    ),
  );

  bool _drawMesh(Canvas canvas, EntryMotionPose pose) {
    final shader = _shader;
    final mesh = _mesh;
    if (_meshFailed || shader == null || mesh == null) return false;
    ui.Vertices? vertices;
    try {
      final deformed = mesh.samplePositions(pose, into: _positions);
      vertices =
          widget.verticesBuilder?.call(
            deformed,
            mesh.textureCoordinates,
            mesh.indices,
          ) ??
          ui.Vertices.raw(
            ui.VertexMode.triangles,
            deformed,
            textureCoordinates: mesh.textureCoordinates,
            indices: mesh.indices,
          );
      canvas.drawVertices(vertices, BlendMode.srcOver, _meshPaint);
      return true;
    } on Object {
      // Latch the fallback without a reentrant setState during paint. Later
      // frames continue drawing the static image and do not retry allocation.
      _meshFailed = true;
      widget.onFallback?.call();
      return false;
    } finally {
      vertices?.dispose();
    }
  }
}

/// Precomputed topology, texture coordinates and facial protection weights.
/// [samplePositions] is deterministic and can also fill a reusable frame buffer.
class EntryCreatureMesh {
  EntryCreatureMesh({required int imageWidth, required int imageHeight})
    : textureCoordinates = Float32List(vertexCount * 2),
      indices = Uint16List(cells * cells * 6) {
    for (var row = 0; row <= cells; row++) {
      for (var column = 0; column <= cells; column++) {
        final index = row * (cells + 1) + column;
        final x = column / cells;
        final y = row / cells;
        textureCoordinates[index * 2] = x * imageWidth;
        textureCoordinates[index * 2 + 1] = y * imageHeight;
        _normalizedX[index] = x;
        _basePositions[index * 2] = x * EntryMotionPose.canvasExtent;
        _basePositions[index * 2 + 1] = y * EntryMotionPose.canvasExtent;

        // Local waves recede before the body's middle. The whole creature can
        // still squash, rotate and translate as a single coherent silhouette.
        final upperWeight = 1 - _smoothStep((y - 0.25) / 0.31);
        final eyeProtection = _outsideEllipse(x, y, 0.548, 0.46, 0.158, 0.15);
        final mouthProtection = _outsideEllipse(x, y, 0.48, 0.624, 0.075, 0.05);
        _waveWeights[index] = upperWeight * eyeProtection * mouthProtection;
        _rippleWeights[index] =
            (1 - _smoothStep((y - 0.25) / 0.18)) *
            eyeProtection *
            mouthProtection;
      }
    }
    var cursor = 0;
    for (var row = 0; row < cells; row++) {
      for (var column = 0; column < cells; column++) {
        final topLeft = row * (cells + 1) + column;
        final bottomLeft = topLeft + cells + 1;
        indices[cursor++] = topLeft;
        indices[cursor++] = topLeft + 1;
        indices[cursor++] = bottomLeft;
        indices[cursor++] = topLeft + 1;
        indices[cursor++] = bottomLeft + 1;
        indices[cursor++] = bottomLeft;
      }
    }
  }

  static const cells = 48;
  static const vertexCount = (cells + 1) * (cells + 1);
  final Float32List textureCoordinates;
  final Uint16List indices;
  final _basePositions = Float32List(vertexCount * 2);
  final _normalizedX = Float32List(vertexCount);
  final _waveWeights = Float32List(vertexCount);
  final _rippleWeights = Float32List(vertexCount);
  final _columnWaves = Float64List(cells + 1);
  final _columnRipples = Float64List(cells + 1);

  Float32List samplePositions(EntryMotionPose pose, {Float32List? into}) {
    final positions = into ?? Float32List(vertexCount * 2);
    assert(positions.length == vertexCount * 2);
    const center = EntryMotionPose.canvasExtent / 2;
    const scale = EntryMotionPose.baseScale;
    final cosine = math.cos(pose.rotationRadians);
    final sine = math.sin(pose.rotationRadians);
    // This bump crosses the visible body's width, not the transparent padding.
    final rippleCenter = 0.18 + 0.64 * pose.rippleProgress;
    const rippleRadius = 0.064;
    // Each column shares its horizontal wave. Preserve double precision and
    // the original Float32 normalized coordinates while evaluating only once.
    for (var column = 0; column <= cells; column++) {
      final x = _normalizedX[column];
      _columnWaves[column] = pose.waveAmplitude == 0
          ? 0
          : pose.waveAmplitude *
                math.sin(
                  2 * math.pi * ((x - 0.2) / 0.6 - 2 * pose.waveProgress),
                );
      _columnRipples[column] = pose.rippleAmplitude == 0
          ? 0
          : -pose.rippleAmplitude *
                _smoothStep(1 - (x - rippleCenter).abs() / rippleRadius);
    }
    for (var vertex = 0; vertex < vertexCount; vertex++) {
      final column = vertex % (cells + 1);
      final mainWave = _columnWaves[column] * _waveWeights[vertex];
      final ripple = _columnRipples[column] * _rippleWeights[vertex];
      final localX =
          (_basePositions[vertex * 2] - center) * scale * pose.scaleX;
      final localY =
          (_basePositions[vertex * 2 + 1] - center) * scale * pose.scaleY +
          mainWave +
          ripple;
      positions[vertex * 2] = center + localX * cosine - localY * sine;
      positions[vertex * 2 + 1] =
          center + localX * sine + localY * cosine + pose.offsetY;
    }
    return positions;
  }
}

class _EntryCreaturePainter extends CustomPainter {
  _EntryCreaturePainter({
    required this.image,
    required this.drawMesh,
    required this.pose,
  });

  final ui.Image image;
  final bool Function(Canvas, EntryMotionPose) drawMesh;
  final EntryMotionPose pose;

  @override
  void paint(Canvas canvas, Size size) {
    // Use the original image draw at both endpoints, avoiding even the tiny
    // sampling differences a tessellated texture can introduce at rest.
    if (pose.isRest || !drawMesh(canvas, pose)) {
      const extent = EntryMotionPose.canvasExtent * EntryMotionPose.baseScale;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(
          center: const Offset(
            EntryMotionPose.canvasExtent / 2,
            EntryMotionPose.canvasExtent / 2,
          ),
          width: extent,
          height: extent,
        ),
        Paint()..filterQuality = FilterQuality.high,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EntryCreaturePainter oldDelegate) =>
      image != oldDelegate.image || pose != oldDelegate.pose;
}

double _outsideEllipse(
  double x,
  double y,
  double centerX,
  double centerY,
  double radiusX,
  double radiusY,
) {
  final dx = (x - centerX) / radiusX;
  final dy = (y - centerY) / radiusY;
  final distance = math.sqrt(dx * dx + dy * dy);
  return _smoothStep((distance - 1.05) / 0.5);
}

double _smoothStep(double t) {
  final clamped = t.clamp(0.0, 1.0);
  return clamped * clamped * (3 - 2 * clamped);
}
