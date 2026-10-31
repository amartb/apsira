package com.apsiralabs.apsira_link

import android.os.Bundle
import android.os.ParcelFileDescriptor
import java.io.IOException
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

// LinkStreams (K2-02a; contract app-link.md §4, §8): an fd in a reply
// becomes a handle, its bytes move through write/read/close/cancel, and
// nothing stays open after a discard or a detach.
@RunWith(RobolectricTestRunner::class)
class LinkStreamsTest {
    private val streams = LinkStreams()
    private val pipes = mutableListOf<ParcelFileDescriptor>()

    /** A pipe: [0] the read end, [1] the write end. */
    private fun pipe(): Array<ParcelFileDescriptor> = ParcelFileDescriptor.createPipe().also { pipes += it }

    @After
    fun closePipes() {
        streams.closeAll()
        for (end in pipes) try { end.close() } catch (e: IOException) { }
    }

    private val unknown = mapOf(LinkClient.UNAVAILABLE to LinkClient.UNKNOWN_ERROR)

    private fun handleOf(value: Any?): Int {
        @Suppress("UNCHECKED_CAST")
        val ref = value as Map<String, Any?>
        assertEquals(setOf(LinkStreams.STREAM), ref.keys)
        return ref[LinkStreams.STREAM] as Int
    }

    private fun readToEnd(handle: Int): ByteArray {
        var out = ByteArray(0)
        while (true) {
            val reply = streams.read(handle, LinkStreams.MAX_READ)
            if (reply[LinkStreams.END] == true) return out
            out += reply[LinkStreams.BYTES] as ByteArray
        }
    }

    @Test
    fun aParcelFileDescriptorInAReplyBecomesAStreamHandle() {
        val (_, write) = pipe()
        val reply = streams.reply(Bundle().apply {
            putParcelable("fd", write)
            putString("ticket", "t-1")
            putBundle("inner", Bundle().apply { putParcelable("fd", pipe()[0]) })
        })

        val handle = handleOf(reply["fd"])
        @Suppress("UNCHECKED_CAST")
        val inner = handleOf((reply["inner"] as Map<String, Any?>)["fd"])
        assertTrue(handle != inner)
        assertEquals("t-1", reply["ticket"])
        assertEquals(2, streams.openCount)
    }

    @Test
    fun aListOfBundlesBecomesAListOfMapsAndStringsStayStrings() {
        fun entry(name: String) = Bundle().apply { putString("name", name); putLong("size", 3L) }
        val reply = streams.reply(Bundle().apply {
            putParcelableArray("entries", arrayOf(entry("a"), entry("b")))
            putParcelableArrayList("items", arrayListOf(entry("c")))
            putStringArray("versions", arrayOf("1.0"))
            putStringArrayList("names", arrayListOf("x"))
        })

        assertEquals(listOf(mapOf("name" to "a", "size" to 3L), mapOf("name" to "b", "size" to 3L)), reply["entries"])
        assertEquals(listOf(mapOf("name" to "c", "size" to 3L)), reply["items"])
        assertEquals(listOf("1.0"), reply["versions"])
        assertEquals(listOf("x"), reply["names"])
    }

    @Test
    fun writeCloseAndReadMoveTheBytesToTheEnd() {
        val (read, write) = pipe()
        val w = streams.register(write)
        val r = streams.register(read)
        val bytes = ByteArray(100_000) { (it * 7).toByte() }

        assertEquals(emptyMap<String, Any?>(), streams.write(w, bytes))
        assertEquals(emptyMap<String, Any?>(), streams.close(w))
        assertArrayEquals(bytes, readToEnd(r))
        assertEquals(emptyMap<String, Any?>(), streams.close(r))
        assertEquals(0, streams.openCount)
    }

    @Test
    fun aReadReturnsAtMostMaxBytes() {
        val (read, write) = pipe()
        val w = streams.register(write)
        val r = streams.register(read)
        streams.write(w, ByteArray(10) { it.toByte() })

        val first = streams.read(r, 4)[LinkStreams.BYTES] as ByteArray
        assertTrue(first.size in 1..4)
    }

    @Test
    fun cancelClosesTheHandleAndTheReaderSeesTheStreamShort() {
        val (read, write) = pipe()
        val w = streams.register(write)
        val r = streams.register(read)
        streams.write(w, byteArrayOf(1, 2, 3))

        assertEquals(emptyMap<String, Any?>(), streams.cancel(w))

        assertEquals(unknown, streams.write(w, byteArrayOf(4)))
        // What was written, then the end: short of any size the writer stated.
        assertArrayEquals(byteArrayOf(1, 2, 3), readToEnd(r))
        assertEquals(1, streams.openCount)
    }

    @Test
    fun anUnknownHandleIsUnknownError() {
        assertEquals(unknown, streams.write(99, byteArrayOf(1)))
        assertEquals(unknown, streams.read(99, 10))
        assertEquals(unknown, streams.close(99))
        assertEquals(unknown, streams.cancel(99))
    }

    @Test
    fun aReadAskingForNothingIsUnknownError() {
        val r = streams.register(pipe()[0])
        assertEquals(unknown, streams.read(r, 0))
    }

    @Test
    fun aWriteThatFailsIsNoAnswerAndDropsTheHandle() {
        val (_, write) = pipe()
        val w = streams.register(write)
        // The descriptor fails under the registry: every write is an IOException.
        write.close()

        assertEquals(mapOf(LinkClient.UNAVAILABLE to LinkClient.NO_ANSWER), streams.write(w, byteArrayOf(1)))
        assertEquals(unknown, streams.write(w, byteArrayOf(1)))
        assertEquals(0, streams.openCount)
    }

    @Test
    fun aReadThatFailsIsNoAnswerAndDropsTheHandle() {
        val (read, _) = pipe()
        val r = streams.register(read)
        read.close()

        assertEquals(mapOf(LinkClient.UNAVAILABLE to LinkClient.NO_ANSWER), streams.read(r, 1))
        assertEquals(0, streams.openCount)
    }

    @Test
    fun releaseClosesTheHandlesOfADiscardedReply() {
        val (read, write) = pipe()
        val reply = streams.reply(Bundle().apply { putParcelable("fd", write) })
        val keep = streams.register(pipe()[0])

        streams.release(mapOf("fields" to reply, "devUnverified" to false))

        assertEquals(unknown, streams.write(handleOf(reply["fd"]), byteArrayOf(1)))
        assertEquals(1, streams.openCount)
        assertEquals(emptyMap<String, Any?>(), streams.close(keep))
        // The write end is closed: the reader sees the end at once.
        assertEquals(-1, ParcelFileDescriptor.AutoCloseInputStream(read).read())
    }

    @Test
    fun aMapThatOnlyLooksLikeAHandleIsNeverReleased() {
        val keep = streams.register(pipe()[0])
        streams.release(mapOf("fields" to mapOf(LinkStreams.STREAM to keep)))
        assertEquals(1, streams.openCount)
    }

    @Test
    fun discardClosesEveryDescriptorOfARawReply() {
        val (read, write) = pipe()
        LinkStreams.discard(Bundle().apply {
            putBundle("inner", Bundle().apply { putParcelable("fd", write) })
        })
        assertEquals(-1, ParcelFileDescriptor.AutoCloseInputStream(read).read())
    }

    @Test
    fun closeAllClosesEveryHandle() {
        val (read, write) = pipe()
        val w = streams.register(write)
        val r = streams.register(pipe()[0])

        streams.closeAll()

        assertEquals(0, streams.openCount)
        assertEquals(unknown, streams.write(w, byteArrayOf(1)))
        assertEquals(unknown, streams.read(r, 1))
        assertEquals(-1, ParcelFileDescriptor.AutoCloseInputStream(read).read())
    }
}
