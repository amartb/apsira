package com.apsiralabs.apsira_jobs

import io.flutter.embedding.engine.plugins.FlutterPlugin

// The Flutter tool builds a plugin's Android half only when the pubspec names a
// pluginClass, so apsira_jobs has this one. It registers nothing: the package's
// Android code is ZoneChangeReceiver, which Android starts from the manifest,
// and the Dart side talks to the workmanager plugin, never to this class.
class ApsiraJobsPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
