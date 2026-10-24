// The plugin side of relay android/app/src/main/kotlin/com/apsiralabs/relay/
// MainActivity.kt @ 09b28810, which registers the zone module in
// configureFlutterEngine, so only the UI engine has it.
package com.apsiralabs.apsira_app

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger

// Flutter attaches a plugin to every engine: the UI engine and each
// background engine another plugin starts (a background job's, an
// alarm's). Only the UI engine attaches to an activity, so the zone
// channel's handler is set when an activity attaches and cleared when it
// goes for good; a background engine never gets it and takes the zone from
// its job's input instead (D-APK-011).
class ApsiraAppPlugin : FlutterPlugin, ActivityAware {
    private var messenger: BinaryMessenger? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        messenger = binding.binaryMessenger
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        messenger = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        messenger?.let { ZoneModule.register(it) }
    }

    // A configuration change (a rotation) detaches and reattaches the same
    // engine's activity: the handler stays, so no call in between fails.
    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        messenger?.let { ZoneModule.register(it) }
    }

    override fun onDetachedFromActivity() {
        messenger?.let { ZoneModule.unregister(it) }
    }
}
