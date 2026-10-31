/// The backup calls of the app link (master-app `contracts/app-link.md`
/// §5.2, D-008, D-APK-026): [ApsiraBackupLink], its channel adapter and the
/// reply types. Its own library, beside `apsira_link.dart`: an app imports
/// only the calls it makes. A backup shipped home is never deleted by an app;
/// every failure is a value.
library;

export 'src/backup_link.dart' hide checkRestoreTarget, linkStreamHandle;
export 'src/channel_backup_link.dart';
export 'src/link_channel.dart' show LinkWritten;
