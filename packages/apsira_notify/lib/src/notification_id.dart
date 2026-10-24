// From relay lib/domain/reminders/window.dart @ 09b28810 (notificationIdFor
// and its FNV-1a); viaticum lib/data/platform/local_notifier.dart @ 78d38e0's
// notificationIntId agrees with it on every ASCII key (D-APK-021).

/// The notification ID of [key]: a 31-bit FNV-1a hash of its UTF-16 code
/// units, so a positive Java `int`. It is the same in every isolate and on
/// every start, so a later notification for the same key (a snooze) replaces
/// the one showing, and the app cancels it without a shared table. Two keys
/// that collide replace each other's notification, never an alarm.
int notificationIdFor(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
