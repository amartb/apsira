// The app link port (contract app-link.md, D-APK-026): what an app calls on
// APSIRA. Every failure is a value; APSIRA missing is unavailable (§1).
import 'package:apsira_core/apsira_core.dart';

import 'link_failure.dart';
import 'link_hello.dart';

/// The deadline of every control call but `notify_policy` (contract §8).
const linkControlDeadline = Duration(seconds: 5);

/// APSIRA, seen from an app. No method throws: APSIRA missing, untrusted,
/// slow or confused is an [Err] with a [LinkUnavailable], and the app behaves
/// as it does without APSIRA.
abstract interface class ApsiraLink {
  /// The versions APSIRA speaks, its version and whether it is locked; the
  /// chosen version is what every later call sends.
  Future<Result<LinkHello, LinkFailure>> hello();
}
