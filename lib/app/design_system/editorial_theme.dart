import 'package:flutter/material.dart';

/// Semantic colors for the black-court editorial visual language.
@immutable
class HoopitoEditorialTheme extends ThemeExtension<HoopitoEditorialTheme> {
  const HoopitoEditorialTheme({
    required this.canvas,
    required this.surface,
    required this.inverseSurface,
    required this.ink,
    required this.mutedInk,
    required this.rule,
    required this.arenaAccent,
    required this.teamBlue,
    required this.teamRed,
    required this.inverseTeamBlue,
    required this.inverseTeamRed,
    required this.foregroundOnTeam,
    required this.focus,
    required this.success,
    required this.warning,
    required this.danger,
  });

  const HoopitoEditorialTheme.light()
    : this(
        canvas: const Color(0xFFF4F3EF),
        surface: const Color(0xFFFFFFFF),
        inverseSurface: const Color(0xFF101112),
        ink: const Color(0xFF101112),
        mutedInk: const Color(0xFF5C6063),
        rule: const Color(0xFF878B8D),
        arenaAccent: const Color(0xFFFF5A1F),
        teamBlue: const Color(0xFF064BA3),
        teamRed: const Color(0xFFA41E29),
        inverseTeamBlue: const Color(0xFF69A1FF),
        inverseTeamRed: const Color(0xFFFF747D),
        foregroundOnTeam: const Color(0xFFF4F3EF),
        focus: const Color(0xFFFF5A1F),
        success: const Color(0xFF176B45),
        warning: const Color(0xFF7A4B00),
        danger: const Color(0xFFA41E29),
      );

  const HoopitoEditorialTheme.dark()
    : this(
        canvas: const Color(0xFF0C0D0E),
        surface: const Color(0xFF151719),
        inverseSurface: const Color(0xFFF4F3EF),
        ink: const Color(0xFFF4F3EF),
        mutedInk: const Color(0xFFAEB3B7),
        rule: const Color(0xFF777D82),
        arenaAccent: const Color(0xFFFF6A32),
        teamBlue: const Color(0xFF69A1FF),
        teamRed: const Color(0xFFFF747D),
        inverseTeamBlue: const Color(0xFF064BA3),
        inverseTeamRed: const Color(0xFFA41E29),
        foregroundOnTeam: const Color(0xFF101112),
        focus: const Color(0xFFFF6A32),
        success: const Color(0xFF55D996),
        warning: const Color(0xFFF5B942),
        danger: const Color(0xFFFF747D),
      );

  final Color canvas;
  final Color surface;
  final Color inverseSurface;
  final Color ink;
  final Color mutedInk;
  final Color rule;
  final Color arenaAccent;
  final Color teamBlue;
  final Color teamRed;
  final Color inverseTeamBlue;
  final Color inverseTeamRed;
  final Color foregroundOnTeam;
  final Color focus;
  final Color success;
  final Color warning;
  final Color danger;

  @override
  HoopitoEditorialTheme copyWith({
    Color? canvas,
    Color? surface,
    Color? inverseSurface,
    Color? ink,
    Color? mutedInk,
    Color? rule,
    Color? arenaAccent,
    Color? teamBlue,
    Color? teamRed,
    Color? inverseTeamBlue,
    Color? inverseTeamRed,
    Color? foregroundOnTeam,
    Color? focus,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return HoopitoEditorialTheme(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      ink: ink ?? this.ink,
      mutedInk: mutedInk ?? this.mutedInk,
      rule: rule ?? this.rule,
      arenaAccent: arenaAccent ?? this.arenaAccent,
      teamBlue: teamBlue ?? this.teamBlue,
      teamRed: teamRed ?? this.teamRed,
      inverseTeamBlue: inverseTeamBlue ?? this.inverseTeamBlue,
      inverseTeamRed: inverseTeamRed ?? this.inverseTeamRed,
      foregroundOnTeam: foregroundOnTeam ?? this.foregroundOnTeam,
      focus: focus ?? this.focus,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  HoopitoEditorialTheme lerp(covariant HoopitoEditorialTheme? other, double t) {
    if (other == null) return this;
    return HoopitoEditorialTheme(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      arenaAccent: Color.lerp(arenaAccent, other.arenaAccent, t)!,
      teamBlue: Color.lerp(teamBlue, other.teamBlue, t)!,
      teamRed: Color.lerp(teamRed, other.teamRed, t)!,
      inverseTeamBlue: Color.lerp(inverseTeamBlue, other.inverseTeamBlue, t)!,
      inverseTeamRed: Color.lerp(inverseTeamRed, other.inverseTeamRed, t)!,
      foregroundOnTeam: Color.lerp(
        foregroundOnTeam,
        other.foregroundOnTeam,
        t,
      )!,
      focus: Color.lerp(focus, other.focus, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
