package com.apsiralabs.apsira_jobs

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// The Flutter tool builds a plugin's Android half only when the pubspec names a
// pluginClass, so apsira_jobs has this one. ZoneChangeReceiver (ZoneResync.kt)
// is started by Android from the manifest; this class answers one channel on
// every engine, the UI's and the background ones:
//
//   channel "apsira_jobs/alarms"
//   "persistentAlarmIds"  the ids android_alarm_manager_plus keeps in
//                         persistent_alarm_ids and re-arms after a reboot
//
// Dart's side is AlarmManagerScheduler.pendingPlatformIds
// (lib/src/alarms/alarm_manager_scheduler.dart), which AlarmSync reads to
// cancel the ids its registry never handed out (D-APK-022).
class ApsiraJobsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        // The name Dart uses (AlarmManagerScheduler.listChannel).
        const val CHANNEL = "apsira_jobs/alarms"

        // android_alarm_manager_plus 5.1.2's AlarmService.SHARED_PREFERENCES_KEY
        // and PERSISTENT_ALARMS_SET_KEY.
        const val ALARM_PREFS = "dev.fluttercommunity.plus.android_alarm_manager_plugin"
        const val PERSISTENT_ALARM_IDS = "persistent_alarm_ids"
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
            .also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "persistentAlarmIds" -> {
                val context = context
                    ?: return result.error("detached", "The plugin is detached", null)
                val ids = context.getSharedPreferences(ALARM_PREFS, Context.MODE_PRIVATE)
                    .getStringSet(PERSISTENT_ALARM_IDS, null)
                    .orEmpty()
                    .mapNotNull { it.toIntOrNull() }
                result.success(ids)
            }
            else -> result.notImplemented()
        }
    }
}
