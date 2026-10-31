# apsira_storage

The storage ports the Apsira apps share, with their Android adapters and test fakes: the
backup folder on the Storage Access Framework, free space over one storage channel (and the
Kotlin that answers it), the document picker, the share sheet and the photo source.
Extracted from RELAY `09b28810`, VIATICUM `78d38e0` and LYCEUM `9f4ff27` (D-APK-015); every
file names its source.

## Consuming

Pin by the shared tag, the same ref for every apsira package (D-APK-007, `../README.md`):

```yaml
dependencies:
  apsira_storage: { git: { url: git@github.com:amartb/apsira.git, ref: apsira-v0.6.0, path: packages/apsira_storage } }
```

`package:apsira_storage/apsira_storage.dart` is the public surface;
`package:apsira_storage/testing.dart` holds the fakes. It depends on `apsira_core` (the
`Result`/`Failure` every port answers), `saf_stream ^4.0.2`, `saf_util ^3.1.1`,
`share_plus ^13.3.1` and `image_picker ^1.2.4`, plus `image_picker_android ^0.8.13+25` and
`image_picker_platform_interface ^2.11.2` at RELAY's pins, which the photo adapter imports to
turn on the system photo picker (ruling R-1 Q2).

```dart
final target = SafBackupTarget();                 // saf_util + saf_stream, free space on the channel
final space = const ChannelStorageSpace();        // freeBytes(treeUri), appFreeBytes()
final picker = SafDocumentPicker();               // pickOne({maxBytes}) or pick() + readAll()
const sharer = SharePlusSharer();
final photos = ImagePickerPhotoSource();          // originals; LYCEUM passes PhotoSizing
```

## What replaces what

| Symbol | Replaces |
|---|---|
| `BackupTarget`, `BackupFolder`, `BackupFile`, `BackupTargetException` | RELAY and LYCEUM `lib/core/ports/backup_target.dart` |
| `SafBackupTarget`, `SafPlugins`, `PluginSaf` | RELAY and LYCEUM `lib/data/platform/saf_backup_target.dart` |
| `StorageSpace`, `ChannelStorageSpace` | LYCEUM `lib/core/ports/storage_space.dart`, `lib/data/platform/channel_storage_space.dart`; VIATICUM `lib/data/platform/free_space_channel.dart` (`folderFreeBytes` is `freeBytes`) |
| `StorageModule.kt`, `ApsiraStoragePlugin` | `android/app/src/main/kotlin/com/apsiralabs/<app>/StorageModule.kt` in all three, and its `MainActivity` line |
| `DocumentPicker`, `PickedDocument`, `DocumentRef` | RELAY and VIATICUM `lib/core/ports/document_picker.dart` (VIATICUM's `PickedDocument` is `DocumentRef`) |
| `SafDocumentPicker`, `PickSafPlugins`, `PluginPickSaf` | RELAY and VIATICUM `lib/data/platform/saf_document_picker.dart` |
| `Sharer`, `ShareOutcome`, `SharePlusSharer` | `lib/core/ports/sharer.dart`, `lib/data/platform/share_plus_sharer.dart` in all three |
| `PhotoSource`, `CapturedPhoto`, `ImagePickerPhotoSource`, `PhotoSizing` | RELAY `lib/core/ports/photo_source.dart`, `lib/data/platform/image_picker_photo_source.dart`; LYCEUM's (its `crop` stays its own) |
| `ImageMeta` | RELAY `lib/domain/media/image_meta.dart` |
| `FakeBackupTarget`, `FakeStorageSpace`, `FakeDocumentPicker`, `FakeSharer`, `FakePhotoSource` (`fixturePhoto`) | each app's `test/fakes/fake_<port>.dart` |

Not here, by design: VIATICUM's `FolderAccess` (folders and files of its own shape),
LYCEUM's crop on `image_cropper` and every media store (D-APK-010 C3).

## Behaviour

- **One channel, `apsira_storage/storage`.** `StorageModule.kt` is VIATICUM's body with the
  channel renamed: `freeBytes` takes a tree URI and answers `StatFs` of the volume a tree
  of Android's external storage provider names (any other provider is null), and
  `appFreeBytes` answers `StatFs(filesDir)`. `ApsiraStoragePlugin` registers it when an
  activity attaches, so only the UI engine has it, as each app's `MainActivity` did; a
  background engine's answers are null. Every free-space answer is null on failure, never
  a throw.
- **`SafBackupTarget`** is RELAY's: every plugin error is a port failure (`storageFull` by
  its errno names, otherwise `folderUnavailable`), names are never replaced, a race SAF
  makes unique is undone. Its `freeBytes` asks the `StorageSpace` it is given.
  APSIRA's adapter of this port is `ApsiraBackupTarget` in `apsira_link` (D-APK-026); this
  package does not depend on it.
- **`DocumentPicker`** has RELAY's `pickOne({maxBytes})` and VIATICUM's `pick({mimeTypes})`
  with `readAll(doc, {maxBytes})`, on one read: 64 KiB chunks pulled one at a time, refused
  before a byte when the reported size is over the cap and at the first chunk past it
  otherwise. A picker that cannot open is a cancel; any read error is
  `documentUnreadable`. `DocumentPicker.documentTooLarge` is the code,
  `DocumentPicker.tooLarge` the failure.
- **`ImagePickerPhotoSource`** passes no sizing by default, so photos are the originals
  (RELAY D-017), typed and sized from their first bytes by `ImageMeta`, with the system
  photo picker for the gallery. `camera:` and `gallery:` take a `PhotoSizing(maxSide:,
  quality:)`.

## Checks

From this directory: `flutter analyze` and `flutter test` (the `storage` gate). The tests
script the SAF seams and the plugins' platform interfaces, the storage and share
channels, and the image picker. They also pin the Kotlin's source to the names the Dart side uses.
`example/` compiles the Kotlin. That app depends on this package by path (its
`pubspec_overrides.yaml` resolves `apsira_core`) and asks `ChannelStorageSpace` for app
storage's free bytes at start; its debug build compiles `ApsiraStoragePlugin.kt` and
`StorageModule.kt` beside the SAF, share and image-picker plugins. `tool/check.sh` runs the
example's analyze and smoke test; the build is run by hand, under a build lease, from
`example/`: `flutter build apk --debug && rm -rf build`.
