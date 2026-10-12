import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum HoopitoOrientationMode { portraitFriendly, landscapeRequired }

const double expandedOrientationShortestSide = 600;

List<DeviceOrientation> preferredOrientationsForWindow(
  HoopitoOrientationMode mode, {
  required double shortestSide,
  double? displayShortestSide,
}) {
  if (mode == HoopitoOrientationMode.landscapeRequired &&
      (displayShortestSide ?? shortestSide) < expandedOrientationShortestSide) {
    return const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];
  }
  return DeviceOrientation.values;
}

class OrientationShell extends StatefulWidget {
  const OrientationShell({required this.mode, required this.child, super.key});

  final HoopitoOrientationMode mode;
  final Widget child;

  @override
  State<OrientationShell> createState() => _OrientationShellState();
}

class _OrientationShellState extends State<OrientationShell> {
  List<DeviceOrientation>? _appliedOrientations;
  bool _edgeToEdgeApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyOrientation();
  }

  @override
  void didUpdateWidget(covariant OrientationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _applyOrientation();
    }
  }

  @override
  void dispose() {
    if (!listEquals(_appliedOrientations, DeviceOrientation.values)) {
      unawaited(
        SystemChrome.setPreferredOrientations(DeviceOrientation.values),
      );
    }
    super.dispose();
  }

  void _applyOrientation() {
    if (!_edgeToEdgeApplied) {
      _edgeToEdgeApplied = true;
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    final orientations = preferredOrientationsForWindow(
      widget.mode,
      shortestSide: MediaQuery.sizeOf(context).shortestSide,
      // Android applies an orientation lock to the whole display. On a
      // split-screen or foldable window, the app's MediaQuery is narrow even
      // though the physical display is large enough to remain adaptive.
      displayShortestSide: _displayShortestSide(context),
    );
    if (listEquals(_appliedOrientations, orientations)) return;
    _appliedOrientations = orientations;
    unawaited(SystemChrome.setPreferredOrientations(orientations));
  }

  double? _displayShortestSide(BuildContext context) {
    final display = View.maybeOf(context)?.display;
    if (display == null || display.devicePixelRatio <= 0) return null;
    final logicalSize = display.size / display.devicePixelRatio;
    return logicalSize.shortestSide;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
