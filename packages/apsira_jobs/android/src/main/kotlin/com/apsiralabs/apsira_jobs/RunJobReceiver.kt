package com.apsiralabs.apsira_jobs

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

// The app's own way into its Dart jobs from Kotlin (K2-02d; contract
// app-link.md §5.3): apsira_link's AppLinkProvider, answering APSIRA's
// backup_now, sends this receiver an explicit in-app broadcast naming the
// app's backup job (the BACKUP_JOB meta-data) in the extra JOB, and the
// receiver queues that job once through ZoneResync.enqueueOnce. The two
// packages have no compile edge: the class name and the extra are constants
// on both sides, pinned by a name test in each (test/run_job_names_test.dart,
// apsira_link's provider_names_test.dart).
//
// Declared in the package manifest, not exported and with no intent filter:
// only the app's own code can reach it. It runs no Dart and logs nothing.
class RunJobReceiver : BroadcastReceiver() {
    companion object {
        // apsira_link's AppLinkProvider.JOB.
        const val JOB = "job"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val job = intent.getStringExtra(JOB)
        if (job.isNullOrBlank()) return
        ZoneResync.enqueueOnce(context, job, emptyMap())
    }
}
