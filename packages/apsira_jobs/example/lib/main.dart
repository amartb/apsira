// A minimal consumer of apsira_jobs: it schedules one periodic job through
// the WorkManager adapter at start, as RELAY and VIATICUM do. Its debug
// build is the proof that the package's Android half compiles (task F1).
import 'package:apsira_jobs/apsira_jobs.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

/// The example's one job.
const exampleJob = 'exampleJob';

/// How often [exampleJob] runs.
const exampleJobPeriod = Duration(hours: 1);

/// WorkManager's background entry point: every job, the zone resync
/// (`reminderResyncJob`) included, has run.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async => true);
}

void main() {
  runApp(ExampleApp(jobs: WorkManagerBackgroundJobs(callbackDispatcher)));
}

/// The example app: schedules [exampleJob] on [jobs] once, at start.
class ExampleApp extends StatefulWidget {
  const ExampleApp({required this.jobs, super.key});

  final BackgroundJobs jobs;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  String _status = 'Scheduling $exampleJob';

  @override
  void initState() {
    super.initState();
    widget.jobs
        .schedulePeriodic(exampleJob, every: exampleJobPeriod)
        .then(
          (_) => 'Scheduled $exampleJob',
          onError: (Object e) => 'Not scheduled: $e',
        )
        .then((status) {
          if (mounted) setState(() => _status = status);
        });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'apsira_jobs example',
    home: Scaffold(body: Center(child: Text(_status))),
  );
}
