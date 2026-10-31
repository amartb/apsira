package com.apsiralabs.apsira_link

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ThreadFactory
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** One call on APSIRA: method, version, extras → the reply LinkClient gives. */
typealias LinkCall = (String, String, Map<String, Any?>) -> Map<String, Any?>

// The channel of LinkChannel (lib/src/link_channel.dart, D-APK-026): `call`
// with exactly `method`, `version` and `extras`, and the stream methods on a
// handle LinkStreams gave. Dart never selects a trust mode (ruling R-2):
// LinkClient resolves and checks APSIRA before any call. Control calls run
// on a pool of CONTROL_THREADS, never the main thread (contract §4), under
// CONTROL_DEADLINE_MS (T1's F-2, K2-02a); stream I/O on its own threads with
// no deadline (§8). Every reply goes back on the main thread, once. Nothing
// is logged.
//
// The requests channel (K2-02d, contract §5.4) is the other direction:
// AppLinkInbox tells every attached engine `offer` (no arguments: the offer
// stays in the inbox) and Dart's ChannelAppLinkRequests answers with
// `takePendingOffer`, which reads and clears the inbox off the main thread.
class ApsiraLinkPlugin internal constructor(
    private val deadlineMs: Long,
    private val newCall: (Context, LinkStreams) -> LinkCall,
) : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        /** LinkChannel.name (test/example_android_test.dart). */
        const val CHANNEL = "apsira_link/link"

        /** The control call. */
        const val METHOD = "call"

        /** The stream methods: LinkChannel's writeMethod … cancelMethod. */
        const val WRITE = "write"
        const val READ = "read"
        const val CLOSE = "close"
        const val CANCEL = "cancel"

        /** The control pool: a hung call holds one thread, never the next call. */
        const val CONTROL_THREADS = 2

        /** Dart's linkControlDeadline: a control call is answered by then, or no_answer. */
        const val CONTROL_DEADLINE_MS = 5_000L

        /** ChannelAppLinkRequests.channelName: requests from APSIRA (K2-02d). */
        const val REQUESTS_CHANNEL = "apsira_link/requests"

        /** `{}` → the offer's map, or null; the inbox is cleared. */
        const val TAKE = "takePendingOffer"

        /** Kotlin → Dart: an offer is waiting. */
        const val OFFER = "offer"
    }

    constructor() : this(CONTROL_DEADLINE_MS, { context, streams -> LinkClient(context, streams = streams)::call })

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var worker: LinkWorker? = null
    private var requests: MethodChannel? = null
    private var offered: (() -> Unit)? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) =
        attach(binding.applicationContext, binding.binaryMessenger)

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = detach()

    internal fun attach(context: Context, messenger: BinaryMessenger) {
        val streams = LinkStreams()
        worker = LinkWorker(newCall(context, streams), streams, deadlineMs)
        channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
        val requests = MethodChannel(messenger, REQUESTS_CHANNEL)
        requests.setMethodCallHandler { call, result ->
            if (call.method != TAKE) return@setMethodCallHandler result.notImplemented()
            val worker = worker ?: return@setMethodCallHandler result.success(null)
            worker.background { AppLinkInbox.take(context).also { main.post { result.success(it) } } }
        }
        this.requests = requests
        val offered: () -> Unit = { main.post { this.requests?.invokeMethod(OFFER, null) } }
        AppLinkInbox.addListener(offered)
        this.offered = offered
    }

    /** Stops the threads and closes every stream handle. */
    internal fun detach() {
        offered?.let { AppLinkInbox.removeListener(it) }
        offered = null
        requests?.setMethodCallHandler(null)
        requests = null
        channel?.setMethodCallHandler(null)
        channel = null
        worker?.shutdown()
        worker = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in setOf(METHOD, WRITE, READ, CLOSE, CANCEL)) {
            result.notImplemented()
            return
        }
        val reply: (Map<String, Any?>) -> Unit = { main.post { result.success(it) } }
        val worker = worker ?: return reply(mapOf(LinkClient.UNAVAILABLE to LinkClient.UNKNOWN_ERROR))
        val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
        if (call.method == METHOD) worker.control(arguments, reply) else worker.stream(call.method, arguments, reply)
    }
}

/**
 * The plugin's threads. A control call carries its arrival time: still
 * queued at the deadline, it is dropped before it reaches APSIRA; running at
 * the deadline, it is answered no_answer then and its late reply discarded
 * (its stream handles closed). Each call is answered exactly once.
 */
internal class LinkWorker(
    private val call: LinkCall,
    private val streams: LinkStreams,
    private val deadlineMs: Long = ApsiraLinkPlugin.CONTROL_DEADLINE_MS,
    threads: Int = ApsiraLinkPlugin.CONTROL_THREADS,
) {
    private val control: ExecutorService = Executors.newFixedThreadPool(threads, daemon("apsira_link-control"))
    private val io: ExecutorService = Executors.newCachedThreadPool(daemon("apsira_link-stream"))
    private val watchdog: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor(daemon("apsira_link-deadline"))

    private companion object {
        const val QUEUED = 0
        const val RUNNING = 1
        const val ANSWERED = 2

        val noAnswer = mapOf(LinkClient.UNAVAILABLE to LinkClient.NO_ANSWER)
        val unknown = mapOf(LinkClient.UNAVAILABLE to LinkClient.UNKNOWN_ERROR)

        fun daemon(name: String) = ThreadFactory { runnable -> Thread(runnable, name).apply { isDaemon = true } }

        fun now(): Long = System.nanoTime() / 1_000_000
    }

    fun control(arguments: Map<*, *>, reply: (Map<String, Any?>) -> Unit) {
        val method = arguments["method"]
        val version = arguments["version"]
        val extras = arguments["extras"]
        if (method !is String || version !is String || extras !is Map<*, *>) return reply(unknown)
        val args = extras.entries.associate { (k, v) -> k.toString() to v }
        val arrival = now()
        val state = AtomicInteger(QUEUED)
        val task = Runnable {
            if (now() - arrival >= deadlineMs) {
                if (state.compareAndSet(QUEUED, ANSWERED)) reply(noAnswer)
                return@Runnable
            }
            if (!state.compareAndSet(QUEUED, RUNNING)) return@Runnable
            val answer = try {
                call(method, version, args)
            } catch (e: RuntimeException) {
                noAnswer
            }
            if (state.compareAndSet(RUNNING, ANSWERED)) reply(answer) else streams.release(answer)
        }
        val future: Future<*>
        try {
            future = control.submit(task)
        } catch (e: RejectedExecutionException) {
            // Detached while the call was arriving.
            if (state.compareAndSet(QUEUED, ANSWERED)) reply(noAnswer)
            return
        }
        try {
            watchdog.schedule({
                if (state.compareAndSet(QUEUED, ANSWERED)) {
                    future.cancel(false)
                    reply(noAnswer)
                } else if (state.compareAndSet(RUNNING, ANSWERED)) {
                    reply(noAnswer)
                }
            }, deadlineMs, TimeUnit.MILLISECONDS)
        } catch (e: RejectedExecutionException) {
            if (state.compareAndSet(QUEUED, ANSWERED)) {
                future.cancel(false)
                reply(noAnswer)
            }
        }
    }

    fun stream(method: String, arguments: Map<*, *>, reply: (Map<String, Any?>) -> Unit) {
        val handle = (arguments["handle"] as? Number)?.toInt() ?: return reply(unknown)
        try {
            io.execute {
                reply(
                    when (method) {
                        ApsiraLinkPlugin.WRITE -> (arguments["bytes"] as? ByteArray)?.let { streams.write(handle, it) } ?: unknown
                        ApsiraLinkPlugin.READ -> (arguments["max"] as? Number)?.let { streams.read(handle, it.toInt()) } ?: unknown
                        ApsiraLinkPlugin.CLOSE -> streams.close(handle)
                        ApsiraLinkPlugin.CANCEL -> streams.cancel(handle)
                        else -> unknown
                    },
                )
            }
        } catch (e: RejectedExecutionException) {
            reply(noAnswer)
        }
    }

    /** Runs [task] on a stream thread (the inbox's file I/O); dropped once detached. */
    fun background(task: () -> Unit) {
        try {
            io.execute(task)
        } catch (e: RejectedExecutionException) {
            // Detached: Dart takes the offer on the next attach.
        }
    }

    /** The engine detached: no new work, every handle closed. */
    fun shutdown() {
        control.shutdownNow()
        watchdog.shutdownNow()
        streams.closeAll()
        io.shutdownNow()
    }
}
