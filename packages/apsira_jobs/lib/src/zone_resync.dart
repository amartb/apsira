// From relay lib/core/ports/background_jobs.dart @ 09b28810
// (reminderResyncJob) and viaticum lib/data/platform/zone_channel.dart
// @ 78d38e0 (ZoneChannel.resyncJob and ZoneChannel.zonePayloadKey).

/// The reminder resync's job name: the package's `ZoneChangeReceiver`
/// (android/…/ZoneResync.kt) enqueues it as a one-time job on a zone change,
/// a clock change, a reboot and an app update, through the workmanager
/// plugin's own worker. The app's background dispatcher maps it to its
/// reminder resync. `ZoneResync.kt` names the same string.
const reminderResyncJob = 'reminderResync';

/// The key of the device's IANA zone in the resync job's input: the
/// receiver writes it as `payload_zoneId`, which the workmanager plugin
/// hands to Dart as `zoneId`.
const zoneIdInputKey = 'zoneId';
