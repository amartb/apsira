package com.apsiralabs.apsira_link

import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle

// The app's side of a call to APSIRA (contract app-link.md §2-§4, §8),
// written from the contract. Before anything is called (§3.2), and closing
// T1's F-3 (K2-02a):
// 1. acquire an unstable ContentProviderClient for the peer's authority
//    (APSIRA, or APSIRA dev in a dev build) first; none is "not_installed";
// 2. resolve the authority: its package must be exactly the peer, else
//    "not_trusted";
// 3. LinkTrust.forPeer must trust it, else "not_trusted";
// 4. call through the client acquired in 1, with `contract`, `version` and
//    the extras, then close it. An APSIRA replaced after the acquire kills
//    the bound process, so the call fails ("no_answer") instead of reaching
//    another installation;
// 5. check 2 and 3 again: a change discards the reply as "not_trusted".
// A descriptor in a discarded reply is closed; one in an answer is a stream
// handle (LinkStreams). Blocking: the plugin runs it off the main thread
// under the deadline. Every failure is a reply, never a throw; nothing is
// logged.
class LinkClient(
    private val context: Context,
    private val ownPackage: String = context.packageName,
    private val devSwitch: Boolean = LinkTrust.devSwitchOn(context),
    private val table: FingerprintTable = LinkTrust.apsiraTable,
    private val streams: LinkStreams = LinkStreams(),
) {
    companion object {
        // The reply keys and the client's own reasons (ruling A-5); the Dart
        // side is LinkChannel.
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
        val trust = LinkTrust.forPeer(ownPackage, devSwitch, table)
        val provider = try {
            context.contentResolver.acquireUnstableContentProviderClient(authority)
        } catch (e: RuntimeException) {
            null
        } ?: return unavailable(NOT_INSTALLED)

        val reply = try {
            when (check(pm, authority, peer, trust)) {
                Check.ABSENT -> return unavailable(NOT_INSTALLED)
                Check.UNTRUSTED -> return unavailable(NOT_TRUSTED)
                Check.TRUSTED -> {}
            }
            val args = toBundle(extras).apply {
                putString("contract", LinkConfig.CONTRACT)
                putString("version", version)
            }
            provider.call(method, null, args)
        } catch (e: Exception) {
            null
        } finally {
            provider.close()
        } ?: return unavailable(NO_ANSWER)

        if (check(pm, authority, peer, trust) != Check.TRUSTED) {
            LinkStreams.discard(reply)
            return unavailable(NOT_TRUSTED)
        }
        if (reply.containsKey(ERROR)) {
            @Suppress("DEPRECATION")
            val code = reply.get(ERROR)
            LinkStreams.discard(reply)
            return if (code is String) mapOf(ERROR to code) else unavailable(UNKNOWN_ERROR)
        }
        return mapOf(FIELDS to streams.reply(reply), DEV_UNVERIFIED to trust.devUnverified)
    }

    private enum class Check { ABSENT, UNTRUSTED, TRUSTED }

    // §3.2: the authority's package is exactly the peer, and trusted now.
    private fun check(pm: PackageManager, authority: String, peer: String, trust: Trust): Check {
        val info = try {
            @Suppress("DEPRECATION")
            pm.resolveContentProvider(authority, 0)
        } catch (e: RuntimeException) {
            null
        } ?: return Check.ABSENT
        if (info.packageName != peer) return Check.UNTRUSTED
        return if (trust.trusts(pm, peer)) Check.TRUSTED else Check.UNTRUSTED
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
}
