/// Periodic background jobs for the Apsira apps that run them (RELAY and
/// VIATICUM): the [BackgroundJobs] port and its [JobConstraints], the
/// WorkManager adapter, and the names the zone-change resync shares with the
/// apps' background dispatchers. The test fake is in `testing.dart`.
library;

export 'src/background_jobs.dart';
export 'src/workmanager_background_jobs.dart';
export 'src/zone_resync.dart';
