import 'package:flutter_test/flutter_test.dart';

/// Advances finite route/coach transitions without waiting for the court's
/// intentional repeating location spotlight to stop scheduling frames.
Future<void> pumpPracticeTransitions(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
