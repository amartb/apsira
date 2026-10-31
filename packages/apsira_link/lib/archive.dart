/// The archive calls of the APSIRA app link (master-app
/// `contracts/atrium-offload.md` §3, §4; D-APK-026): the [ApsiraArchiveLink]
/// port ATRIUM uses to offload kept documents, and its channel adapter.
/// Only `com.apsiralabs.atrium` may call them; APSIRA refuses any other app
/// with `not_authorised`.
library;

export 'src/archive_link.dart' hide linkArchiveUnknown;
export 'src/channel_archive_link.dart';
