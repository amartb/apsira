// The example's smoke test: at start it schedules its one job through the
// BackgroundJobs port (the fake here; WorkManagerBackgroundJobs on a device)
// and says so.
import 'package:apsira_jobs/testing.dart';
import 'package:apsira_jobs_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('schedules the example job once at start', (tester) async {
    final jobs = FakeBackgroundJobs();

    await tester.pumpWidget(ExampleApp(jobs: jobs));
    await tester.pump();

    expect(await jobs.scheduled(), {exampleJob: exampleJobPeriod});
    expect(find.text('Scheduled $exampleJob'), findsOneWidget);
  });
}
