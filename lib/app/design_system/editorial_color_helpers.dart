import 'package:flutter/material.dart';

import 'package:hoopito/app/design_system/editorial_tokens.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

Color teamColorForScheme(
  TeamSide side,
  ColorScheme scheme, {
  Color? background,
}) {
  final lightAccent = background == null
      ? scheme.brightness == Brightness.dark
      : background.computeLuminance() < 0.35;
  if (lightAccent) {
    return side == TeamSide.red
        ? HoopitoColors.redLight
        : HoopitoColors.blueLight;
  }
  return side == TeamSide.red ? HoopitoColors.red : HoopitoColors.blue;
}

Color accessibleForegroundFor(Color background) {
  const candidates = [Colors.black, Colors.white];
  final backgroundLuminance = background.computeLuminance();
  for (final candidate in candidates) {
    final foregroundLuminance = candidate.computeLuminance();
    final lighter = foregroundLuminance > backgroundLuminance
        ? foregroundLuminance
        : backgroundLuminance;
    final darker = foregroundLuminance > backgroundLuminance
        ? backgroundLuminance
        : foregroundLuminance;
    if ((lighter + 0.05) / (darker + 0.05) >= 4.5) return candidate;
  }
  return Colors.black;
}
