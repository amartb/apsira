// The plugin side of viaticum android/app/src/main/kotlin/com/apsiralabs/
// viaticum/MainActivity.kt @ 78d38e0 (and RELAY's and LYCEUM's), which
// registers the storage module in configureFlutterEngine, so only the UI
// engine has it (D-APK-015).
package com.apsiralabs.apsira_storage

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger

// Flutter attaches a plugin to every engine: the UI engine and each
// background engine another plugin starts (a background job's). Only the UI
// engine attaches to an activity, so the storage channel's handler is set
// when an activity attaches; a background engine never gets it, and its
// free-space answers are null, as in each app before.
class ApsiraStoragePlugin : FlutterPlugin, ActivityAware {
    private var messenger: BinaryMessenger? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        messenger = binding.binaryMessenger
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        messenger = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        register()
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        register()
    }

    // The handler stays when the activity goes, as MainActivity's did: the
    // engine is still the UI engine, and the module holds the application
    // context only.
    override fun onDetachedFromActivity() {}

    private fun register() {
        val context = context ?: return
        messenger?.let { StorageModule.register(it, context) }
    }
}
