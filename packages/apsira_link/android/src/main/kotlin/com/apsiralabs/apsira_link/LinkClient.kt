package com.apsiralabs.apsira_link

import android.content.Context
import android.net.Uri
import android.os.Bundle

// The app's side of a call to APSIRA (contract app-link.md §2-§4, §8),
// written from the contract. Before anything is called (§3.2):
// 1. resolve the peer's authority (APSIRA, or APSIRA dev in a dev build);
//    none is "not_installed";
// 2. its package must be exactly the peer, else "not_trusted";
// 3. LinkTrust.forPeer must trust it, else "not_trusted".
// Then ContentResolver.call with `contract`, `version` and the extras.
// Blocking: the plugin runs it off the main thread, and Dart holds the
// deadline. Every failure is a reply, never a throw; nothing is logged.
class LinkClient(
    private val context: Context,
    private val ownPackage: String = context.packageName,
    private val devSwitch: Boolean = LinkTrust.devSwitchOn(context),
    private val table: FingerprintTable = LinkTrust.apsiraTable,
) {
    companion object {
        // The reply keys and the client's own reasons (ruling A-5); the Dart
        // side is ChannelApsiraLink.
        const val UNAVAILABLE = "unavailable"
        const val ERROR = "error"
        const val FIELDS = "fields"
        const val DEV_UNVERIFIED = "devUnverified"
        const val NOT_INSTALLED = "not_installed"
        const val NOT_TRUSTED = "not_trusted"
        const val NO_ANSWER = "no_answer"
        const val UNKNOWN_ERROR = "unknown_error"
    }

    /** [method] on APSIRA: `{unavailable}`, `{error}` or `{fields, devUnverified}`. */
    fun call(method: String, version: String, extras: Map<String, Any?>): Map<String, Any?> {
        val pm = context.packageManager
        val peer = LinkTrust.peer(ownPackage, devSwitch)
        val authority = peer + LinkConfig.AUTHORITY_SUFFIX
        val info = try {
            @Suppress("DEPRECATION")
            pm.resolveContentProvider(authority, 0)
        } catch (e: RuntimeException) {
            null
        } ?: return unavailable(NOT_INSTALLED)
        if (info.packageName != peer) return unavailable(NOT_TRUSTED)
        val trust = LinkTrust.forPeer(ownPackage, devSwitch, table)
        if (!trust.trusts(pm, peer)) return unavailable(NOT_TRUSTED)

        val reply = try {
            val args = toBundle(extras).apply {
                putString("contract", LinkConfig.CONTRACT)
                putString("version", version)
            }
            context.contentResolver.call(Uri.parse("content://$authority"), method, null, args)
        } catch (e: Exception) {
            null
        } ?: return unavailable(NO_ANSWER)

        if (reply.containsKey(ERROR)) {
            @Suppress("DEPRECATION")
            val code = reply.get(ERROR)
            return if (code is String) mapOf(ERROR to code) else unavailable(UNKNOWN_ERROR)
        }
        return mapOf(FIELDS to toMap(reply), DEV_UNVERIFIED to trust.devUnverified)
    }

    private fun unavailable(reason: String): Map<String, Any?> = mapOf(UNAVAILABLE to reason)

    // Dart's extras into a Bundle: the StandardMessageCodec's types; a list
    // of strings is a string array (contract §4's "string array").
    private fun toBundle(map: Map<String, Any?>): Bundle = Bundle().apply {
        for ((key, value) in map) {
            when (value) {
                null -> putString(key, null)
                is String -> putString(key, value)
                is Boolean -> putBoolean(key, value)
                is Int -> putInt(key, value)
                is Long -> putLong(key, value)
                is Double -> putDouble(key, value)
                is ByteArray -> putByteArray(key, value)
                is List<*> -> putStringArray(key, value.map { it as String }.toTypedArray())
                is Map<*, *> -> putBundle(key, toBundle(value.entries.associate { (k, v) -> k.toString() to v }))
                else -> throw IllegalArgumentException("unsupported extra")
            }
        }
    }

    // APSIRA's Bundle into what the method channel carries. A value the
    // codec cannot carry (a ParcelFileDescriptor arrives only with the T2
    // calls) is left out rather than failing the reply.
    private fun toMap(bundle: Bundle): Map<String, Any?> {
        val out = mutableMapOf<String, Any?>()
        for (key in bundle.keySet()) {
            @Suppress("DEPRECATION")
            val value = bundle.get(key)
            when (value) {
                null, is String, is Boolean, is Int, is Long, is Double,
                is ByteArray, is IntArray, is LongArray, is DoubleArray -> out[key] = value
                is Float -> out[key] = value.toDouble()
                is Array<*> -> out[key] = value.toList().filterIsInstance<String>()
                is List<*> -> out[key] = value.filterIsInstance<String>()
                is Bundle -> out[key] = toMap(value)
            }
        }
        return out
    }
}
