// AC-12.4 (D-APK-017): the tour player's golden matrix probe, English and
// Spanish × dark and light × 100 % and 200 % (apsira_test's goldenMatrix):
// the step with taps, as first open plays it. Update with
// `flutter test --update-goldens test/goldens/tour_player_golden_test.dart`
// and name the re-approval in the commit.
import 'package:apsira_test/apsira_test.dart';

import '../support/host.dart';
import '../support/tour.dart';

void main() {
  goldenMatrix(
    'tour_player',
    (_) => sampleTourScreen(initialStep: 1),
    host: host,
  );
}
