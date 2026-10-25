// From viaticum android/app/src/main/kotlin/com/apsiralabs/viaticum/
// StorageModule.kt @ 78d38e0, on the channel apsira_storage/storage
// (D-APK-015).
package com.apsiralabs.apsira_storage

import android.content.Context
import android.net.Uri
import android.os.StatFs
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

// The storage module, as RELAY D-116 (ported from RELAY's StorageModule.kt
// @ f37051f; P4-05a), for a reviewer who does not read Kotlin: the method
// channel "apsira_storage/storage", which Dart's ChannelStorageSpace calls,
// answers the bytes free on a volume, or null when it cannot tell.
//
// - "appFreeBytes" (VIATICUM's addition): the free bytes of the volume that
//   holds the app's own files directory, where photos/ lives (07 §6.1).
// - "freeBytes" (RELAY's, kept as it is) takes a picked folder's tree URI.
//   SAF gives an app no free space: a provider's roots carry
//   COLUMN_AVAILABLE_BYTES, but querying them needs MANAGE_DOCUMENTS, which
//   only the system's file picker holds. A tree of Android's own external
//   storage provider names its volume in its document ID ("primary:Backups",
//   or "1A2B-3C4D:Backups" on an SD card), so its free space is that
//   volume's (StatFs). Any other provider (a cloud drive, say) answers null.
//
// StatFs reads the file system's own counters: no permission is needed.
// ApsiraStoragePlugin registers it on the UI engine only.
object StorageModule {
    // The name Dart uses: ChannelStorageSpace.channelName in
    // lib/src/channel_storage_space.dart.
    private const val CHANNEL = "apsira_storage/storage"
    private const val EXTERNAL_STORAGE = "com.android.externalstorage.documents"

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "appFreeBytes" -> result.success(StatFs(context.filesDir.path).availableBytes)
                "freeBytes" -> result.success(freeBytes(context, call.argument<String>("uri")))
                else -> result.notImplemented()
            }
        }
    }

    // The free bytes of the volume the tree [uri] is on; null when it is not
    // a tree of the external storage provider or the volume is not mounted.
    fun freeBytes(context: Context, uri: String?): Long? {
        val tree = Uri.parse(uri ?: return null)
        if (tree.authority != EXTERNAL_STORAGE) return null
        return try {
            val volume = DocumentsContract.getTreeDocumentId(tree).substringBefore(':')
            volumeDirectory(context, volume)?.let { StatFs(it.path).availableBytes }
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    // "primary" is the phone's shared storage; another ID is a removable
    // volume's UUID.
    private fun volumeDirectory(context: Context, volume: String): File? {
        val storage = context.getSystemService(StorageManager::class.java) ?: return null
        val found = if (volume == "primary") {
            storage.primaryStorageVolume
        } else {
            storage.storageVolumes.firstOrNull { it.uuid.equals(volume, ignoreCase = true) }
        }
        return found?.directory
    }
}
