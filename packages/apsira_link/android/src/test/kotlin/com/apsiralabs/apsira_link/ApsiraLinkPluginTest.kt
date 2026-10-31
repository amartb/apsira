package com.apsiralabs.apsira_link

import android.os.Bundle
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf

// ApsiraLinkPlugin (K2-02a, T1's F-2): control calls on a pool of
// CONTROL_THREADS, each answered once; a call still queued at the deadline
// is never sent, a hung one is answered no_answer at the deadline and its
// late reply discarded; every stream handle is closed on detach.
@RunWith(RobolectricTestRunner::class)
class ApsiraLinkPluginTest {
    /** A messenger that only holds the handler the channel registers. */
    private class Messenger : BinaryMessenger {
        override fun send(channel: String, message: ByteBuffer?) {}
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {}
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {}
    }

    /** One MethodChannel.Result, recording every answer it is given. */
    private class Answer : MethodChannel.Result {
        val replies: MutableList<Any?> = Collections.synchronizedList(mutableListOf<Any?>())
        var notImplemented = false

        override fun success(result: Any?) { replies += result }
        override fun error(code: String, message: String?, details: Any?) { replies += "error:$code" }
        override fun notImplemented() { notImplemented = true }
    }

    private val app = RuntimeEnvironment.getApplication()
    private val messenger = Messenger()
    private val release = CountDownLatch(1)
    private val sent: MutableList<String> = Collections.synchronizedList(mutableListOf<String>())
    private var streams: LinkStreams? = null
    private var plugin: ApsiraLinkPlugin? = null

    /** APSIRA's stand-in: `hang` blocks until [release]; anything else answers at once. */
    private fun attach(deadlineMs: Long = ApsiraLinkPlugin.CONTROL_DEADLINE_MS, reply: (LinkStreams) -> Map<String, Any?> = { ok }): ApsiraLinkPlugin =
        ApsiraLinkPlugin(deadlineMs) { _, s ->
            streams = s
            val apsira: LinkCall = { method, _, _ ->
                sent += method
                if (method == "hang") release.await(30, TimeUnit.SECONDS)
                reply(s)
            }
            apsira
        }.also {
            it.attach(app, messenger)
            plugin = it
        }

    @After
    fun detach() {
        release.countDown()
        plugin?.detach()
    }

    private val ok: Map<String, Any?> = mapOf(LinkClient.FIELDS to emptyMap<String, Any?>(), LinkClient.DEV_UNVERIFIED to false)
    private val noAnswer = mapOf(LinkClient.UNAVAILABLE to LinkClient.NO_ANSWER)

    private fun call(plugin: ApsiraLinkPlugin, method: String, extras: Map<String, Any?> = emptyMap()): Answer =
        Answer().also {
            plugin.onMethodCall(MethodCall(ApsiraLinkPlugin.METHOD, mapOf("method" to method, "version" to "1.0", "extras" to extras)), it)
        }

    /** Runs the main looper until [done] or [timeoutMs]; the replies are posted there. */
    private fun until(timeoutMs: Long = 3_000, done: () -> Boolean): Boolean {
        val end = System.nanoTime() + timeoutMs * 1_000_000
        while (System.nanoTime() < end) {
            shadowOf(Looper.getMainLooper()).idle()
            if (done()) return true
            Thread.sleep(5)
        }
        shadowOf(Looper.getMainLooper()).idle()
        return done()
    }

    @Test
    fun thePoolAndTheDeadlineAreTheContract() {
        assertEquals(2, ApsiraLinkPlugin.CONTROL_THREADS)
        assertEquals(5_000L, ApsiraLinkPlugin.CONTROL_DEADLINE_MS)
        assertEquals("apsira_link/link", ApsiraLinkPlugin.CHANNEL)
        assertEquals(listOf("call", "write", "read", "close", "cancel"),
            listOf(ApsiraLinkPlugin.METHOD, ApsiraLinkPlugin.WRITE, ApsiraLinkPlugin.READ, ApsiraLinkPlugin.CLOSE, ApsiraLinkPlugin.CANCEL))
    }

    @Test
    fun aHungCallDoesNotDelayASecondOne() {
        val plugin = attach()
        val hung = call(plugin, "hang")
        assertTrue(until { sent.contains("hang") })

        val started = System.nanoTime()
        val second = call(plugin, "hello")

        assertTrue(until(1_000) { second.replies.isNotEmpty() })
        assertTrue(System.nanoTime() - started < 1_000_000_000L)
        assertEquals(listOf<Any?>(ok), second.replies)
        assertTrue(hung.replies.isEmpty())
    }

    @Test
    fun aCallStillQueuedAtTheDeadlineIsNeverSentAndIsNoAnswer() {
        val plugin = attach(deadlineMs = 300)
        val first = call(plugin, "hang")
        val second = call(plugin, "hang")
        assertTrue(until { sent.size == 2 })

        val queued = call(plugin, "backup_begin")

        assertTrue(until { queued.replies.isNotEmpty() && first.replies.isNotEmpty() && second.replies.isNotEmpty() })
        assertEquals(listOf<Any?>(noAnswer), queued.replies)
        release.countDown()
        Thread.sleep(200)
        until(200) { false }
        assertEquals(listOf("hang", "hang"), sent.toList())
        assertEquals(listOf<Any?>(noAnswer), queued.replies)
    }

    @Test
    fun theWatchdogAnswersNoAnswerAtTheDeadlineAndTheLateReplyIsDropped() {
        val plugin = attach(deadlineMs = 300)
        val started = System.nanoTime()
        val hung = call(plugin, "hang")

        assertTrue(until { hung.replies.isNotEmpty() })
        val elapsedMs = (System.nanoTime() - started) / 1_000_000
        assertTrue("answered after ${elapsedMs}ms", elapsedMs in 290..2_000)
        assertEquals(listOf<Any?>(noAnswer), hung.replies)

        release.countDown()
        Thread.sleep(200)
        until(200) { false }
        assertEquals(listOf<Any?>(noAnswer), hung.replies)
    }

    @Test
    fun aLateReplyClosesTheStreamsItCarries() {
        val pipe = ParcelFileDescriptor.createPipe()
        var handle = -1
        val plugin = attach(deadlineMs = 200) { s ->
            val reply = s.reply(Bundle().apply { putParcelable("fd", pipe[1]) })
            @Suppress("UNCHECKED_CAST")
            handle = (reply["fd"] as Map<String, Any?>)[LinkStreams.STREAM] as Int
            mapOf(LinkClient.FIELDS to reply, LinkClient.DEV_UNVERIFIED to false)
        }
        val hung = call(plugin, "hang")
        assertTrue(until { hung.replies.isNotEmpty() })

        release.countDown()
        assertTrue(until { handle >= 0 && streams!!.openCount == 0 })
        assertEquals(-1, ParcelFileDescriptor.AutoCloseInputStream(pipe[0]).read())
    }

    @Test
    fun theStreamMethodsReachTheStreams() {
        val plugin = attach()
        val pipe = ParcelFileDescriptor.createPipe()
        call(plugin, "hello")
        assertTrue(until { streams != null })
        val w = streams!!.register(pipe[1])
        val r = streams!!.register(pipe[0])

        fun stream(method: String, args: Map<String, Any?>): Answer =
            Answer().also { plugin.onMethodCall(MethodCall(method, args), it) }

        val written = stream(ApsiraLinkPlugin.WRITE, mapOf("handle" to w, "bytes" to byteArrayOf(1, 2, 3)))
        assertTrue(until { written.replies.isNotEmpty() })
        assertEquals(listOf<Any?>(emptyMap<String, Any?>()), written.replies)
        val closed = stream(ApsiraLinkPlugin.CLOSE, mapOf("handle" to w))
        assertTrue(until { closed.replies.isNotEmpty() })
        val read = stream(ApsiraLinkPlugin.READ, mapOf("handle" to r, "max" to 65_536))
        assertTrue(until { read.replies.isNotEmpty() })
        @Suppress("UNCHECKED_CAST")
        assertEquals(listOf<Byte>(1, 2, 3), ((read.replies.single() as Map<String, Any?>)[LinkStreams.BYTES] as ByteArray).toList())
        val cancelled = stream(ApsiraLinkPlugin.CANCEL, mapOf("handle" to r))
        assertTrue(until { cancelled.replies.isNotEmpty() })
        assertEquals(0, streams!!.openCount)

        val unknown = stream(ApsiraLinkPlugin.READ, mapOf("handle" to 4242, "max" to 1))
        val malformed = stream(ApsiraLinkPlugin.WRITE, mapOf("handle" to "one"))
        assertTrue(until { unknown.replies.isNotEmpty() && malformed.replies.isNotEmpty() })
        val unknownError = mapOf(LinkClient.UNAVAILABLE to LinkClient.UNKNOWN_ERROR)
        assertEquals(listOf<Any?>(unknownError), unknown.replies)
        assertEquals(listOf<Any?>(unknownError), malformed.replies)
    }

    @Test
    fun detachClosesEveryHandle() {
        val plugin = attach()
        call(plugin, "hello")
        assertTrue(until { streams != null })
        val pipe = ParcelFileDescriptor.createPipe()
        streams!!.register(pipe[1])
        streams!!.register(ParcelFileDescriptor.createPipe()[0])

        plugin.detach()
        this.plugin = null

        assertEquals(0, streams!!.openCount)
        assertEquals(-1, ParcelFileDescriptor.AutoCloseInputStream(pipe[0]).read())
    }

    @Test
    fun anUnknownMethodIsNotImplementedAndMalformedArgumentsAreUnknownError() {
        val plugin = attach()
        val other = Answer().also { plugin.onMethodCall(MethodCall("dance", null), it) }
        assertTrue(other.notImplemented)

        val malformed = Answer().also { plugin.onMethodCall(MethodCall(ApsiraLinkPlugin.METHOD, mapOf("method" to 1)), it) }
        assertTrue(until { malformed.replies.isNotEmpty() })
        assertEquals(listOf<Any?>(mapOf(LinkClient.UNAVAILABLE to LinkClient.UNKNOWN_ERROR)), malformed.replies)
        assertTrue(sent.isEmpty())
    }

    @Test
    fun theDefaultPluginAsksTheRealClient() {
        val plugin = ApsiraLinkPlugin().also { it.attach(app, messenger); this.plugin = it }
        val answer = call(plugin, "hello")
        assertTrue(until { answer.replies.isNotEmpty() })
        assertEquals(listOf<Any?>(mapOf(LinkClient.UNAVAILABLE to LinkClient.NOT_INSTALLED)), answer.replies)
    }

    @Test
    fun aCallAfterDetachIsAnsweredAtOnce() {
        val plugin = attach()
        plugin.detach()
        this.plugin = null
        val answer = call(plugin, "hello")
        assertTrue(until { answer.replies.isNotEmpty() })
        assertEquals(listOf<Any?>(mapOf(LinkClient.UNAVAILABLE to LinkClient.UNKNOWN_ERROR)), answer.replies)
        assertTrue(sent.isEmpty())
    }
}
