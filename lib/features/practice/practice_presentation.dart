import 'package:flutter/foundation.dart';

enum PracticeStep {
  pregame,
  scoreBlueTwo,
  undo,
  courtPoint,
  scoreRedTwo,
  missBlue,
  finish,
  result;

  int get number => switch (this) {
    pregame => 1,
    scoreBlueTwo => 2,
    undo => 3,
    courtPoint || scoreRedTwo => 4,
    missBlue => 5,
    finish => 6,
    result => 7,
  };
}

/// Presentation-only guidance. All practice records belong to a separate
/// in-memory command session; this object never writes match data.
class PracticePresentation {
  const PracticePresentation({
    required this.step,
    required this.onExit,
    this.showCoach = true,
  });
  final PracticeStep step;
  final VoidCallback onExit;

  /// The lesson and its action guards are independent of coach visibility.
  final bool showCoach;
}
