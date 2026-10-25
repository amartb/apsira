// The FLAG_SECURE half of relay lib/data/platform/screen_privacy.dart @
// 09b28810, which set it through flutter_windowmanager_plus; the package's
// own Kotlin instead (D-APK-016, ruling R-1 Q3).
package com.apsiralabs.apsira_lock

import android.app.Activity
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// "Hide in recent apps": with FLAG_SECURE on the activity's window the recents
// switcher shows a blank card and the system refuses screenshots and screen
// recordings of the app. One method on one channel:
//
//   channel "apsira_lock/screen_privacy", method "setHidden", argument a bool
//
// Dart's side is lib/src/screen_privacy.dart (FlagSecureScreenPrivacy).
class ScreenPrivacyModule : MethodChannel.MethodCallHandler {
    companion object {
        // The name Dart uses (FlagSecureScreenPrivacy.channelName).
        const val CHANNEL = "apsira_lock/screen_privacy"
    }

    // The activity the flag goes on; null between activities.
    var activity: Activity? = null
        set(value) {
            field = value
            apply()
        }

    // The last state Dart asked for. Android does not keep a window flag
    // when it recreates the activity, so every activity attached gets it.
    private var hidden = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "setHidden") return result.notImplemented()
        hidden = call.arguments as? Boolean ?: false
        if (activity == null) {
            return result.error("noActivity", "No activity to set FLAG_SECURE on", null)
        }
        apply()
        result.success(null)
    }

    private fun apply() {
        val window = activity?.window ?: return
        if (hidden) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
