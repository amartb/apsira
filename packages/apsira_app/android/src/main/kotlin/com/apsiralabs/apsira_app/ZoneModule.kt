// From lyceum android/app/src/main/kotlin/com/apsiralabs/lyceum/ZoneModule.kt
// @ 9f4ff27 (the channel half of relay's ZoneModule.kt @ 09b28810), on the
// channel apsira_app/zone.
package com.apsiralabs.apsira_app

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

// Dart cannot read the phone's IANA time-zone name (it only knows an
// abbreviation such as "CET"), so this file answers one question on one
// channel:
//
//   channel "apsira_app/zone", method "zoneId"  ->  e.g. "Europe/Madrid"
//
// Dart's side is lib/src/zone_channel.dart. ApsiraAppPlugin registers it on
// the UI engine only; background engines never see it and take the zone
// from their job's input.
object ZoneModule {
    // The name Dart uses (ZoneChannel.name in zone_channel.dart).
    private const val CHANNEL = "apsira_app/zone"

    // Answers "zoneId" on [messenger], the UI engine's channel endpoint.
    // Android updates the process's default zone when the user changes it,
    // so every call reads the current one.
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "zoneId") {
                result.success(TimeZone.getDefault().id)
            } else {
                result.notImplemented()
            }
        }
    }

    // Clears the handler on [messenger]: a call then gets
    // MissingPluginException, as on an engine that never had it.
    fun unregister(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(null)
    }
}
