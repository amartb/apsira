package com.apsiralabs.apsira_link

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor

// The app's provider for APSIRA's calls (contract app-link.md §2, §3.2,
// §5.3, §5.4; D-034; K2-02d), written from the contract. Each adopting app
// declares it in its own manifest, never the library's (no app gains an
// exported provider by a package bump):
//
//   <provider android:name="com.apsiralabs.apsira_link.AppLinkProvider"
//       android:authorities="${applicationId}.apsira" android:exported="true"
//       android:grantUriPermissions="false" />
//
// with no permission attributes. `call` is the only entry point; the others
// throw. On every call, before anything else is read: the caller must be
// exactly APSIRA (APSIRA dev in a dev build, LinkTrust's selection) and
// certificate-trusted now, else `not_authorised` and nothing else, and
// nothing is logged about it. Then `contract` and the major of `version`
// must be this contract's 1, else `unsupported_version` (an unknown method
// too: it is not in the version this app speaks).
//
// backup_now: the app opts in to the central schedule by its manifest
// meta-data BACKUP_JOB naming its Dart backup job; the provider sends an
// explicit in-app broadcast to apsira_jobs' non-exported RunJobReceiver
// (extra JOB), which queues that job once. No compile edge: the receiver's
// class name and the extra are constants on both sides, pinned by a name
// test in each package. Without the meta-data or the receiver, accepted =
// false (the app is on its own schedule).
//
// restore_offer: a whole offer goes to AppLinkInbox (the newest replaces an
// older one) and to every attached engine; accepted = true means the app
// will show its own confirmation. A malformed offer is `not_found`.
class AppLinkProvider internal constructor(
    private val table: FingerprintTable,
    private val ownPackage: String? = null,
    private val devSwitch: Boolean? = null,
) : ContentProvider() {
    companion object {
        /** Each app's authority is its id + this (contract §2). */
        const val AUTHORITY_SUFFIX = ".apsira"

        /** The methods on the app (§5.3, §5.4). */
        const val BACKUP_NOW = "backup_now"
        const val RESTORE_OFFER = "restore_offer"

        /** The reply keys and codes (§8). */
        const val ERROR = "error"
        const val ACCEPTED = "accepted"
        const val NOT_AUTHORISED = "not_authorised"
        const val UNSUPPORTED_VERSION = "unsupported_version"
        const val NOT_FOUND = "not_found"

        /** The major this side speaks (§9). */
        const val MAJOR = "1"

        /** The meta-data naming the app's Dart backup job (Dart `appLinkBackupJob`). */
        const val BACKUP_JOB = "com.apsiralabs.apsira_link.BACKUP_JOB"

        /** apsira_jobs' receiver and its extra (apsira_jobs RunJobReceiver.kt). */
        const val RUN_JOB_RECEIVER = "com.apsiralabs.apsira_jobs.RunJobReceiver"
        const val JOB = "job"
    }

    constructor() : this(LinkTrust.apsiraTable)

    override fun onCreate(): Boolean = true

    override fun call(method: String, arg: String?, extras: Bundle?): Bundle {
        val context = context ?: return error(NOT_AUTHORISED)
        if (!callerTrusted(context)) return error(NOT_AUTHORISED)
        if (extras == null || !speaksThisContract(extras)) return error(UNSUPPORTED_VERSION)
        return when (method) {
            BACKUP_NOW -> accepted(backupNow(context))
            RESTORE_OFFER -> restoreOffer(context, extras)
            else -> error(UNSUPPORTED_VERSION)
        }
    }

    // §3.2: getCallingPackage now, against the trust this build selects.
    private fun callerTrusted(context: Context): Boolean {
        val caller = try {
            callingPackage
        } catch (e: SecurityException) {
            null
        }
        val own = ownPackage ?: context.packageName
        val switch = devSwitch ?: LinkTrust.devSwitchOn(context)
        return CallerCheck.allows(context.packageManager, caller, LinkTrust.forPeer(own, switch, table))
    }

    private fun speaksThisContract(extras: Bundle): Boolean {
        val version = extras.getString("version") ?: return false
        return extras.getString("contract") == LinkConfig.CONTRACT && version.substringBefore('.') == MAJOR
    }

    private fun backupNow(context: Context): Boolean {
        val job = try {
            context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
                .metaData?.getString(BACKUP_JOB)
        } catch (e: Exception) {
            null
        }
        if (job.isNullOrEmpty()) return false
        val intent = Intent()
            .setClassName(context.packageName, RUN_JOB_RECEIVER)
            .setPackage(context.packageName)
            .putExtra(JOB, job)
        return try {
            if (context.packageManager.queryBroadcastReceivers(intent, 0).isEmpty()) return false
            context.sendBroadcast(intent)
            true
        } catch (e: RuntimeException) {
            false
        }
    }

    private fun restoreOffer(context: Context, extras: Bundle): Bundle {
        @Suppress("DEPRECATION")
        val offer = AppLinkInbox.offer { extras.get(it) } ?: return error(NOT_FOUND)
        return accepted(AppLinkInbox.put(context, offer))
    }

    private fun accepted(value: Boolean) = Bundle().apply { putBoolean(ACCEPTED, value) }

    private fun error(code: String) = Bundle().apply { putString(ERROR, code) }

    // §2: call is the only entry point.

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor =
        throw UnsupportedOperationException()

    override fun insert(uri: Uri, values: ContentValues?): Uri = throw UnsupportedOperationException()

    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException()

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = throw UnsupportedOperationException()

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor = throw UnsupportedOperationException()

    override fun getType(uri: Uri): String? = null
}
