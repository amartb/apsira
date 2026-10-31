package com.apsiralabs.apsira_link

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

// The channel of ChannelApsiraLink (lib/src/channel_apsira_link.dart,
// D-APK-026): one method, `call`, with exactly `method`, `version` and
// `extras`. Dart never selects a trust mode (ruling R-2): LinkClient
// resolves and checks APSIRA before any call, on one background thread
// (no call blocks the main thread, contract §4); the reply goes back on
// the main thread. Nothing is logged.
class ApsiraLinkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        /** ChannelApsiraLink.channelName (test/example_android_test.dart). */
        const val CHANNEL = "apsira_link/link"

        /** The one method Dart invokes. */
        const val METHOD = "call"
    }

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var client: LinkClient? = null
    private var worker: ExecutorService? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        client = LinkClient(binding.applicationContext)
        worker = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        worker?.shutdown()
        worker = null
        client = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != METHOD) {
            result.notImplemented()
            return
        }
        val method = call.argument<Any?>("method")
        val version = call.argument<Any?>("version")
        val extras = call.argument<Any?>("extras")
        val client = client
        val worker = worker
        if (method !is String || version !is String || extras !is Map<*, *> || client == null || worker == null) {
            result.success(mapOf(LinkClient.UNAVAILABLE to LinkClient.UNKNOWN_ERROR))
            return
        }
        val args = extras.entries.associate { (k, v) -> k.toString() to v }
        try {
            worker.execute {
                val reply = try {
                    client.call(method, version, args)
                } catch (e: RuntimeException) {
                    mapOf(LinkClient.UNAVAILABLE to LinkClient.NO_ANSWER)
                }
                main.post { result.success(reply) }
            }
        } catch (e: RejectedExecutionException) {
            // Detached while the call was arriving.
            result.success(mapOf(LinkClient.UNAVAILABLE to LinkClient.NO_ANSWER))
        }
    }
}
