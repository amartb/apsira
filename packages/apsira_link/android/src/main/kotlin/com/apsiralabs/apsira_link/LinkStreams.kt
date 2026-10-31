package com.apsiralabs.apsira_link

import android.os.Bundle
import android.os.ParcelFileDescriptor
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.AbstractMap.SimpleImmutableEntry
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

// The byte streams of the app link (contract app-link.md §4, §8; K2-02a):
// the ParcelFileDescriptor ends APSIRA hands back (`fd`), registered by an
// integer handle Dart reads and writes through the plugin's write, read,
// close and cancel. A reply's Bundle reaches Dart through reply(): an fd is
// {stream: <handle>}, a list of Bundles a list of maps. Stream I/O has no
// deadline; it ends with the sender's stated size, which Dart checks with
// the SHA-256. Every failure is a reply, never a throw; nothing is logged.
class LinkStreams {
    companion object {
        const val STREAM = "stream"
        const val BYTES = "bytes"
        const val END = "end"

        /** The most one read returns (Dart's LinkChannel.chunkSize). */
        const val MAX_READ = 64 * 1024

        /** Closes every descriptor in [bundle], nested ones too: a reply that is discarded. */
        fun discard(bundle: Bundle) {
            for (key in bundle.keySet()) discardValue(@Suppress("DEPRECATION") bundle.get(key))
        }

        private fun discardValue(value: Any?) {
            when (value) {
                is ParcelFileDescriptor -> closeQuietly(value)
                is Bundle -> discard(value)
                is Array<*> -> value.forEach { discardValue(it) }
                is List<*> -> value.forEach { discardValue(it) }
            }
        }

        private fun closeQuietly(pfd: ParcelFileDescriptor) {
            try {
                pfd.close()
            } catch (e: IOException) {
            }
        }
    }

    /** `{stream: <handle>}` in a converted reply; release() closes only these. */
    private class Ref(handle: Int) : AbstractMap<String, Any?>() {
        override val entries: Set<Map.Entry<String, Any?>> = setOf(SimpleImmutableEntry(STREAM, handle))
    }

    /** One open end: its descriptor, and the stream over it once used. */
    private class End(val pfd: ParcelFileDescriptor) {
        private var input: InputStream? = null
        private var output: OutputStream? = null

        fun input(): InputStream = input ?: ParcelFileDescriptor.AutoCloseInputStream(pfd).also { input = it }

        fun output(): OutputStream = output ?: ParcelFileDescriptor.AutoCloseOutputStream(pfd).also { output = it }

        // Closing a stream closes its descriptor; a second close is a no-op.
        fun close() {
            for (closeable in listOfNotNull(output, input, pfd)) {
                try {
                    closeable.close()
                } catch (e: Exception) {
                }
            }
        }

        // A reliable pipe's reader sees the error; a plain pipe just ends
        // short, which the reader discards (contract §8).
        fun cancel() {
            try {
                pfd.closeWithError("cancelled")
            } catch (e: Exception) {
            }
            close()
        }
    }

    private val open = ConcurrentHashMap<Int, End>()
    private val next = AtomicInteger(1)

    /** How many handles are open. */
    val openCount: Int get() = open.size

    /** Registers [pfd] and returns its handle. */
    fun register(pfd: ParcelFileDescriptor): Int {
        val handle = next.getAndIncrement()
        open[handle] = End(pfd)
        return handle
    }

    /** APSIRA's Bundle as the method channel carries it, its descriptors registered. */
    fun reply(bundle: Bundle): Map<String, Any?> {
        val out = mutableMapOf<String, Any?>()
        for (key in bundle.keySet()) {
            @Suppress("DEPRECATION")
            val value = bundle.get(key)
            when (value) {
                null, is String, is Boolean, is Int, is Long, is Double,
                is ByteArray, is IntArray, is LongArray, is DoubleArray -> out[key] = value
                is Float -> out[key] = value.toDouble()
                is ParcelFileDescriptor -> out[key] = Ref(register(value))
                is Bundle -> out[key] = reply(value)
                is Array<*> -> out[key] = list(value.toList())
                is List<*> -> out[key] = list(value)
                // Anything else the codec cannot carry is left out rather
                // than failing the reply.
            }
        }
        return out
    }

    // A string array stays strings; an array or list of Bundles (AL §5.2
    // `entries`, AO §3 `items`) is a list of maps.
    private fun list(values: List<*>): List<Any?> =
        if (values.any { it is Bundle }) {
            values.filterIsInstance<Bundle>().map { reply(it) }
        } else {
            values.filterIsInstance<String>()
        }

    /** Closes every handle [reply] (a converted reply that is discarded) carries. */
    fun release(reply: Any?) {
        when (reply) {
            is Ref -> remove(reply[STREAM] as Int)?.close()
            is Map<*, *> -> reply.values.forEach { release(it) }
            is List<*> -> reply.forEach { release(it) }
        }
    }

    /** Writes [bytes] to [handle]'s write end: `{}`, or no_answer and the handle closed. */
    fun write(handle: Int, bytes: ByteArray): Map<String, Any?> {
        val end = open[handle] ?: return unknown()
        return synchronized(end) {
            try {
                end.output().apply {
                    write(bytes)
                    flush()
                }
                emptyMap()
            } catch (e: IOException) {
                drop(handle)
            }
        }
    }

    /** Up to [max] bytes from [handle]'s read end: `{bytes}`, `{end: true}`, or no_answer and the handle closed. */
    fun read(handle: Int, max: Int): Map<String, Any?> {
        if (max < 1) return unknown()
        val end = open[handle] ?: return unknown()
        return synchronized(end) {
            try {
                val buffer = ByteArray(minOf(max, MAX_READ))
                val n = end.input().read(buffer)
                if (n < 0) mapOf(END to true) else mapOf(BYTES to buffer.copyOf(n))
            } catch (e: IOException) {
                drop(handle)
            }
        }
    }

    /** Closes [handle]: the stream ended as it should. */
    fun close(handle: Int): Map<String, Any?> {
        val end = remove(handle) ?: return unknown()
        end.close()
        return emptyMap()
    }

    /** Closes [handle] abandoned: the peer sees the stream short. */
    fun cancel(handle: Int): Map<String, Any?> {
        val end = remove(handle) ?: return unknown()
        end.cancel()
        return emptyMap()
    }

    /** Closes every handle (the engine detached). */
    fun closeAll() {
        for (handle in open.keys.toList()) remove(handle)?.close()
    }

    private fun remove(handle: Int): End? = open.remove(handle)

    private fun drop(handle: Int): Map<String, Any?> {
        remove(handle)?.close()
        return mapOf(LinkClient.UNAVAILABLE to LinkClient.NO_ANSWER)
    }

    private fun unknown(): Map<String, Any?> = mapOf(LinkClient.UNAVAILABLE to LinkClient.UNKNOWN_ERROR)
}
