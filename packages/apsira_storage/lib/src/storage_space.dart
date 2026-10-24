// From lyceum lib/core/ports/storage_space.dart @ 9f4ff27, with viaticum
// lib/data/platform/free_space_channel.dart @ 78d38e0's folderFreeBytes as
// freeBytes (D-APK-015).

/// Free space: of the volume a picked folder is on (RELAY's backup folder
/// warning, RELAY D-116) and of the app's own storage (what a restore or a
/// photo import checks first).
abstract interface class StorageSpace {
  /// The bytes free on the volume that holds the SAF tree [treeUri], or
  /// null when they cannot be measured (a provider that is not a local
  /// volume, a volume not mounted). Never throws.
  Future<int?> freeBytes(String treeUri);

  /// The bytes free on the storage that holds the app's own files, or null
  /// when they cannot be measured. Never throws: an unmeasurable space lets
  /// the caller proceed, and a full disk part-way is still caught as
  /// `ENOSPC`.
  Future<int?> appFreeBytes();
}
