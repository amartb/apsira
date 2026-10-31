/// APSIRA's adapter of `apsira_storage`'s unchanged `BackupTarget` port
/// (master-app `contracts/app-link.md` §5.1; ruling R-2, D-APK-026): an app
/// gives it to its backup code instead of, or beside, its SAF target, and its
/// backups go home through APSIRA. Its own library, beside `backups.dart`.
library;

export 'src/apsira_backup_target.dart';
