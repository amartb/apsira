# apsira_storage changelog

One section per release, naming any migration a consumer must make. Every package shares
one tag, `apsira-vX.Y.Z` (D-APK-007).

## 0.4.0 — 2026-10-24

No change in behaviour. Migration: move every apsira `ref:` to
`apsira-v0.4.0`.

## 0.3.0 — 2026-10-24

First release (D-APK-015, ruling R-1 Q2): RELAY `09b28810`'s `BackupTarget` with
`SafBackupTarget`, `PhotoSource` with `ImagePickerPhotoSource` and `ImageMeta`, and `Sharer`
with `SharePlusSharer`. `StorageSpace` takes LYCEUM's `appFreeBytes` and VIATICUM's folder
free space, and `DocumentPicker` unions RELAY's and VIATICUM's members. VIATICUM's
`StorageModule.kt` serves the one channel `apsira_storage/storage`, which `ApsiraStoragePlugin`
registers on the UI engine. The apps' fakes are unioned in `testing.dart`.

**Every app.** Delete `StorageModule.kt` and its `MainActivity` registration, and the copies
of the ports, adapters and fakes this package holds (README, "What replaces what").

**Migration for RELAY.** The channel `relay/storage` becomes `apsira_storage/storage`; a
test that mocks it uses `SafBackupTarget.storageChannelName`. `ImageMeta` and its fixtures
move here. Nothing else changes.

**Migration for VIATICUM.** `FreeSpaceChannel` becomes `ChannelStorageSpace`
(`folderFreeBytes` → `freeBytes`). `PickedDocument` becomes `DocumentRef`, and
`DocumentPicker.documentTooLarge` (the failure) becomes `DocumentPicker.tooLarge`. Reads
take 64 KiB chunks instead of 1 MiB. A picker that cannot open is now a cancel, and a read
error that is not a `PlatformException` is now `documentUnreadable`. `FolderAccess` stays.

**Migration for LYCEUM.** `share_plus` 12 → 13 (the adapter is this package's, so only
the pin moves). `PhotoSource` gains `recoverLost` and loses `crop`, which stays a LYCEUM
port. `ImagePickerPhotoSource(camera: PhotoSizing(maxSide: <defaultPhotoQuality>,
quality: 90), gallery: PhotoSizing(quality: 90))` keeps its capture sizes. Photos now
carry their upright size, and the gallery opens the system photo picker.
