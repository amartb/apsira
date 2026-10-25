// The three screens relay lib/data/platform/local_notifier.dart,
// alarm_manager_scheduler.dart and record_audio_recorder.dart @ 09b28810
// opened through app_settings 9.0.1, as its AppSettingsPlugin.kt starts them;
// the package's own Kotlin instead (D-APK-021, ruling R-2 Q4-c).
package com.apsiralabs.apsira_notify

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// One method per screen on one channel, none with an argument:
//
//   channel "apsira_notify/settings"
//   "openNotificationSettings"         the app's notification settings
//   "openBatteryOptimisationSettings"  the battery-optimisation list
//   "openAppDetails"                   the app's details page
//
// A screen that cannot start falls back to the app's details page, as
// app_settings does. Dart's side is lib/src/system_settings.dart
// (ChannelSystemSettings).
class NotifySettingsModule : MethodChannel.MethodCallHandler {
    companion object {
        // The name Dart uses (ChannelSystemSettings.channelName).
        const val CHANNEL = "apsira_notify/settings"
    }

    // The activity the screen opens from; null between activities.
    var activity: Activity? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val activity = activity
            ?: return result.error("noActivity", "No activity to open the settings from", null)
        when (call.method) {
            "openNotificationSettings" -> open(activity, notificationSettings(activity))
            "openBatteryOptimisationSettings" ->
                open(activity, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            "openAppDetails" -> activity.startActivity(appDetails(activity))
            else -> return result.notImplemented()
        }
        result.success(null)
    }

    // From Android 8 a page of the app's own channels; before it, the details.
    private fun notificationSettings(activity: Activity): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
        } else {
            appDetails(activity)
        }

    private fun appDetails(activity: Activity): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", activity.packageName, null))

    private fun open(activity: Activity, intent: Intent) {
        try {
            activity.startActivity(intent)
        } catch (e: Exception) {
            // No screen answers the intent on this phone: the app's details.
            activity.startActivity(appDetails(activity))
        }
    }
}
