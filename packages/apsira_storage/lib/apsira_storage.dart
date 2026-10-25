/// The storage ports every Apsira app shares and their Android adapters
/// (D-APK-015): the SAF backup folder, free space over the storage channel
/// `apsira_storage/storage`, the document picker, the share sheet and the
/// photo source. Fakes are in `package:apsira_storage/testing.dart`.
library;

export 'src/backup_target.dart';
export 'src/channel_storage_space.dart';
export 'src/document_picker.dart';
export 'src/image_meta.dart';
export 'src/image_picker_photo_source.dart';
export 'src/photo_source.dart';
export 'src/saf_backup_target.dart';
export 'src/saf_document_picker.dart';
export 'src/share_plus_sharer.dart';
export 'src/sharer.dart';
export 'src/storage_space.dart';
