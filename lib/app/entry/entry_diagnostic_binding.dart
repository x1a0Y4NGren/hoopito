import 'package:flutter/widgets.dart';
import 'package:hoopito/core/diagnostics/startup_diagnostics.dart';

/// Profile-only framework spans include deferred frames that are not submitted
/// to the engine and therefore cannot appear in FrameTiming raster samples.
class EntryDiagnosticBinding extends WidgetsFlutterBinding {
  @override
  void drawFrame() {
    StartupDiagnostics.measureSync('framework_frame', super.drawFrame);
  }
}
