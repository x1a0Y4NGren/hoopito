import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:hoopito/app/entry/entry_motion_pose.dart';
import 'package:hoopito/core/diagnostics/startup_diagnostics.dart';

const entryBrandAsset = 'assets/icons/hoopito-app-icon-foreground.png';

/// Decode for the physical size of the fixed native/Flutter canvas. The
/// approved source remains unchanged and the caller owns the returned image.
Future<ui.Image> decodeEntryBrandImage({
  required double devicePixelRatio,
}) async {
  final assetStarted = StartupDiagnostics.start();
  final data = await StartupDiagnostics.measureSync(
    'image_asset_call',
    () => rootBundle.load(entryBrandAsset),
  );
  StartupDiagnostics.end('image_asset', assetStarted);
  final targetWidth =
      (EntryMotionPose.canvasExtent *
              EntryMotionPose.baseScale *
              devicePixelRatio)
          .ceil();
  final codecStarted = StartupDiagnostics.start();
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    targetWidth: targetWidth,
    allowUpscaling: false,
  );
  StartupDiagnostics.end('image_codec', codecStarted);
  try {
    final frameStarted = StartupDiagnostics.start();
    final frame = await StartupDiagnostics.measureSync(
      'image_frame_call',
      codec.getNextFrame,
    );
    StartupDiagnostics.end('image_frame', frameStarted);
    return frame.image;
  } finally {
    codec.dispose();
  }
}
