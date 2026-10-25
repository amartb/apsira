/// Test support for apps that schedule through `apsira_jobs`: the
/// [FakeBackgroundJobs], and [alarmManagerBackupExclusions], what an app on
/// `AlarmManagerScheduler` adds to `apsira_notify`'s `alarmBackupExclusions`
/// in its backup-rules check.
library;

import 'package:apsira_notify/testing.dart';

export 'src/fake_background_jobs.dart';

/// android_alarm_manager_plus's SharedPreferences file
/// (`AlarmService.SHARED_PREFERENCES_KEY` in its `AlarmService.java`), which
/// holds `persistent_alarm_ids` and each alarm's settings and params: its
/// boot receiver re-arms them, so an app's backup rules exclude it beside
/// the registry (D-APK-022).
const alarmManagerBackupExclusions = [
  BackupPath.sharedPref(
    'dev.fluttercommunity.plus.android_alarm_manager_plugin.xml',
  ),
];
