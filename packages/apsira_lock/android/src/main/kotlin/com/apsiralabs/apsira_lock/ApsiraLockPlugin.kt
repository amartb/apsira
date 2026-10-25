// The registration RELAY left to flutter_windowmanager_plus (relay
// pubspec.yaml @ 09b28810); the package's own plugin instead (D-APK-016).
package com.apsiralabs.apsira_lock

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

// The channel answers on every engine; only the UI engine attaches to an
// activity, so only its window ever takes the flag. A background engine's
// call gets the "noActivity" error, which the Dart side logs.
class ApsiraLockPlugin : FlutterPlugin, ActivityAware {
    private var channel: MethodChannel? = null
    private val screenPrivacy = ScreenPrivacyModule()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, ScreenPrivacyModule.CHANNEL)
            .also { it.setMethodCallHandler(screenPrivacy) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        screenPrivacy.activity = binding.activity
    }

    // A configuration change (a rotation) recreates the activity: the new
    // window gets the flag again before its first frame.
    override fun onDetachedFromActivityForConfigChanges() {
        screenPrivacy.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        screenPrivacy.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        screenPrivacy.activity = null
    }
}
