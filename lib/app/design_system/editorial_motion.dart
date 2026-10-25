import 'dart:ui' as ui;

import 'package:flutter/material.dart';

@immutable
class HoopitoMotionTheme extends ThemeExtension<HoopitoMotionTheme> {
  const HoopitoMotionTheme({
    required this.scoreFlight,
    required this.impact,
    required this.acceleratedScoreFlight,
    required this.acceleratedImpact,
    required this.reducedReveal,
    required this.press,
    required this.state,
    required this.sheet,
    required this.pageReveal,
    required this.foulStamp,
    required this.undo,
    required this.entry,
    required this.entryReduced,
    required this.entrySkip,
    required this.entryPreferenceWait,
  });

  const HoopitoMotionTheme.light()
    : this(
        scoreFlight: const Duration(milliseconds: 480),
        impact: const Duration(milliseconds: 180),
        acceleratedScoreFlight: const Duration(milliseconds: 320),
        acceleratedImpact: const Duration(milliseconds: 120),
        reducedReveal: const Duration(milliseconds: 120),
        press: const Duration(milliseconds: 90),
        state: const Duration(milliseconds: 180),
        sheet: const Duration(milliseconds: 220),
        pageReveal: const Duration(milliseconds: 220),
        foulStamp: const Duration(milliseconds: 180),
        undo: const Duration(milliseconds: 180),
        entry: const Duration(milliseconds: 1000),
        entryReduced: const Duration(milliseconds: 140),
        entrySkip: const Duration(milliseconds: 120),
        entryPreferenceWait: const Duration(milliseconds: 80),
      );

  const HoopitoMotionTheme.dark() : this.light();

  final Duration scoreFlight;
  final Duration impact;
  final Duration acceleratedScoreFlight;
  final Duration acceleratedImpact;
  final Duration reducedReveal;
  final Duration press;
  final Duration state;
  final Duration sheet;
  final Duration pageReveal;
  final Duration foulStamp;
  final Duration undo;
  final Duration entry;
  final Duration entryReduced;
  final Duration entrySkip;
  final Duration entryPreferenceWait;

  Duration get scoreTransition => state;
  Duration get splash => impact;

  @override
  HoopitoMotionTheme copyWith({
    Duration? scoreFlight,
    Duration? impact,
    Duration? acceleratedScoreFlight,
    Duration? acceleratedImpact,
    Duration? reducedReveal,
    Duration? press,
    Duration? state,
    Duration? scoreTransition,
    Duration? sheet,
    Duration? pageReveal,
    Duration? foulStamp,
    Duration? undo,
    Duration? entry,
    Duration? entryReduced,
    Duration? entrySkip,
    Duration? entryPreferenceWait,
  }) {
    return HoopitoMotionTheme(
      scoreFlight: scoreFlight ?? this.scoreFlight,
      impact: impact ?? this.impact,
      acceleratedScoreFlight:
          acceleratedScoreFlight ?? this.acceleratedScoreFlight,
      acceleratedImpact: acceleratedImpact ?? this.acceleratedImpact,
      reducedReveal: reducedReveal ?? this.reducedReveal,
      press: press ?? this.press,
      state: state ?? scoreTransition ?? this.state,
      sheet: sheet ?? this.sheet,
      pageReveal: pageReveal ?? this.pageReveal,
      foulStamp: foulStamp ?? this.foulStamp,
      undo: undo ?? this.undo,
      entry: entry ?? this.entry,
      entryReduced: entryReduced ?? this.entryReduced,
      entrySkip: entrySkip ?? this.entrySkip,
      entryPreferenceWait: entryPreferenceWait ?? this.entryPreferenceWait,
    );
  }

  @override
  HoopitoMotionTheme lerp(covariant HoopitoMotionTheme? other, double t) {
    if (other == null) return this;
    Duration blend(Duration a, Duration b) => Duration(
      microseconds: ui
          .lerpDouble(
            a.inMicroseconds.toDouble(),
            b.inMicroseconds.toDouble(),
            t,
          )!
          .round(),
    );
    return HoopitoMotionTheme(
      scoreFlight: blend(scoreFlight, other.scoreFlight),
      impact: blend(impact, other.impact),
      acceleratedScoreFlight: blend(
        acceleratedScoreFlight,
        other.acceleratedScoreFlight,
      ),
      acceleratedImpact: blend(acceleratedImpact, other.acceleratedImpact),
      reducedReveal: blend(reducedReveal, other.reducedReveal),
      press: blend(press, other.press),
      state: blend(state, other.state),
      sheet: blend(sheet, other.sheet),
      pageReveal: blend(pageReveal, other.pageReveal),
      foulStamp: blend(foulStamp, other.foulStamp),
      undo: blend(undo, other.undo),
      entry: blend(entry, other.entry),
      entryReduced: blend(entryReduced, other.entryReduced),
      entrySkip: blend(entrySkip, other.entrySkip),
      entryPreferenceWait: blend(
        entryPreferenceWait,
        other.entryPreferenceWait,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HoopitoMotionTheme &&
      other.scoreFlight == scoreFlight &&
      other.impact == impact &&
      other.acceleratedScoreFlight == acceleratedScoreFlight &&
      other.acceleratedImpact == acceleratedImpact &&
      other.reducedReveal == reducedReveal &&
      other.press == press &&
      other.state == state &&
      other.sheet == sheet &&
      other.pageReveal == pageReveal &&
      other.foulStamp == foulStamp &&
      other.undo == undo &&
      other.entry == entry &&
      other.entryReduced == entryReduced &&
      other.entrySkip == entrySkip &&
      other.entryPreferenceWait == entryPreferenceWait;

  @override
  int get hashCode => Object.hash(
    scoreFlight,
    impact,
    acceleratedScoreFlight,
    acceleratedImpact,
    reducedReveal,
    press,
    state,
    sheet,
    pageReveal,
    foulStamp,
    undo,
    entry,
    entryReduced,
    entrySkip,
    entryPreferenceWait,
  );
}

typedef HoopitoMotionTokens = HoopitoMotionTheme;
