/// The app side of the APSIRA app link (master-app `contracts/app-link.md`,
/// D-APK-026): the [ApsiraLink] port, its channel adapter and the typed
/// failures. APSIRA missing, untrusted or slow is unavailable, never a throw.
library;

export 'src/apsira_link.dart';
export 'src/channel_apsira_link.dart';
export 'src/link_dev_switch.dart';
export 'src/link_failure.dart';
export 'src/link_hello.dart';
