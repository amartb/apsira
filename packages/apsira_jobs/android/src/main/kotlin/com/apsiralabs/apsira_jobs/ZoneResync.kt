package com.apsiralabs.apsira_jobs

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker
import dev.fluttercommunity.workmanager.PAYLOAD_PREFIX
import java.util.TimeZone

// From relay android/app/src/main/kotlin/com/apsiralabs/relay/ZoneModule.kt
// @ 09b28810 (byte-identical in viaticum @ 78d38e0 but for its package and
// channel): the zone module's second half, ZoneChangeReceiver and
// enqueueResync, with the package renamed (K2-02d adds enqueueOnce beside
// it, sharing its request). The first half, the "<app>/zone"
// method channel, is apsira_app's.
//
// Nothing in the apps' plugins listens for a zone change, so
// ZoneChangeReceiver does: Android calls it when the zone or the clock
// changes, after a reboot and after an app update (the package manifest
// lists the four broadcasts). It runs no Dart. It only asks WorkManager to
// run the Dart job "reminderResync" once, through the workmanager plugin's
// own worker, with the zone ID in the job's input.
object ZoneResync {
    // The name Dart uses: reminderResyncJob in lib/src/zone_resync.dart.
    private const val RESYNC_JOB = "reminderResync"

    // Queues one reminder resync. The workmanager plugin's BackgroundWorker
    // starts a background Dart engine at the app's dispatcher and runs the
    // job named by DART_TASK_KEY; keys under PAYLOAD_PREFIX reach Dart as
    // the job's input ("zoneId", zoneIdInputKey), so the job knows the zone
    // without the channel. Using the plugin's constants, not copies of their
    // strings, makes a rename in the plugin fail the build rather than the
    // resync.
    //
    // The unique name and APPEND_OR_REPLACE mean: if a resync is already
    // running, this one runs after it (never cancelling it); if the last
    // one failed, this one replaces it. Several broadcasts in a row (boot
    // then a zone change) therefore queue runs, which are idempotent.
    fun enqueueResync(context: Context, zoneId: String) {
        val input = Data.Builder()
            .putString(BackgroundWorker.DART_TASK_KEY, RESYNC_JOB)
            .putString("${PAYLOAD_PREFIX}zoneId", zoneId)
            .build()
        WorkManager.getInstance(context)
            .enqueueUniqueWork(RESYNC_JOB, ExistingWorkPolicy.APPEND_OR_REPLACE, dartJob(input))
    }

    // The same mechanism for any Dart job (K2-02d: RunJobReceiver): the
    // plugin's BackgroundWorker runs [job], each [payload] entry reaching
    // Dart under PAYLOAD_PREFIX, unique by the job's name with
    // APPEND_OR_REPLACE, as above. enqueueResync keeps its own lines, which
    // the resync contract test reads, and shares the request.
    fun enqueueOnce(context: Context, job: String, payload: Map<String, String>) {
        val input = Data.Builder()
            .putString(BackgroundWorker.DART_TASK_KEY, job)
        for ((key, value) in payload) input.putString("$PAYLOAD_PREFIX$key", value)
        WorkManager.getInstance(context)
            .enqueueUniqueWork(job, ExistingWorkPolicy.APPEND_OR_REPLACE, dartJob(input.build()))
    }

    private fun dartJob(input: Data): OneTimeWorkRequest =
        OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
            .setInputData(input)
            .build()
}

// Declared in the package's AndroidManifest.xml, not exported: only the system
// sends it these broadcasts. Before the app's first start the plugin has no
// Dart dispatcher yet, so the job fails at once; there is nothing to resync
// then.
class ZoneChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // A zone change names the new zone in its extra; the
                // process default may not have caught up yet.
                val zone = intent.getStringExtra(Intent.EXTRA_TIMEZONE)
                    ?: TimeZone.getDefault().id
                ZoneResync.enqueueResync(context, zone)
            }
        }
    }
}
