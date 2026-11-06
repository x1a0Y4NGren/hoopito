import 'package:integration_test/integration_test.dart';
import '../test/app/practice_journey_test.dart' as journey;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  journey.runPracticeJourney(device: true);
}
