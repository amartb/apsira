// The registration RELAY left to app_settings (relay pubspec.yaml @
// 09b28810); the package's own plugin instead (D-APK-021, ruling R-2 Q4-c).
package com.apsiralabs.apsira_notify

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

// The channel answers on every engine; only the UI engine attaches to an
// activity, so only it can open a screen. A background engine's call gets the
// "noActivity" error.
class ApsiraNotifyPlugin : FlutterPlugin, ActivityAware {
    private var channel: MethodChannel? = null
    private val settings = NotifySettingsModule()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, NotifySettingsModule.CHANNEL)
            .also { it.setMethodCallHandler(settings) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        settings.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        settings.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        settings.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        settings.activity = null
    }
}
