/// Periodic background jobs for the Apsira apps that run them (RELAY and
/// VIATICUM): the [BackgroundJobs] port and its [JobConstraints], the
/// WorkManager adapter, the names the zone-change resync shares with the
/// apps' background dispatchers, and the [AlarmManagerScheduler] of
/// `apsira_notify`'s alarm registry with its fire entry [onAlarmFired]
/// (D-APK-022). The test fake is in `testing.dart`.
library;

export 'src/alarms/alarm_manager_scheduler.dart';
export 'src/background_jobs.dart';
export 'src/workmanager_background_jobs.dart';
export 'src/zone_resync.dart';
