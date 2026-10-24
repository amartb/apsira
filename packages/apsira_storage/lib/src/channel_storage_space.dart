// From lyceum lib/data/platform/channel_storage_space.dart @ 9f4ff27 and
// viaticum lib/data/platform/free_space_channel.dart @ 78d38e0, on the
// package's channel (D-APK-015).
import 'package:flutter/services.dart' show MethodChannel;

import 'storage_space.dart';

/// The [StorageSpace] on the storage module's channel (`StorageModule.kt`):
/// `freeBytes` answers `StatFs` of the volume a tree of Android's external
/// storage provider names, `appFreeBytes` `StatFs(filesDir)`.
/// `ApsiraStoragePlugin` registers the module on the UI engine only, so a
/// background engine's answer is null.
final class ChannelStorageSpace implements StorageSpace {
  const ChannelStorageSpace();

  /// The storage module's channel; `SafBackupTarget.freeBytes` asks it too.
  static const channelName = 'apsira_storage/storage';

  static const _channel = MethodChannel(channelName);

  @override
  Future<int?> freeBytes(String treeUri) => _ask('freeBytes', {'uri': treeUri});

  @override
  Future<int?> appFreeBytes() => _ask('appFreeBytes');

  /// Null when the module cannot measure, errs or is missing: never throws.
  static Future<int?> _ask(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<int>(method, arguments);
    } catch (_) {
      return null;
    }
  }
}
