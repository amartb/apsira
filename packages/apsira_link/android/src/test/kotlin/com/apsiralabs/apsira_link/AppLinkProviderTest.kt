package com.apsiralabs.apsira_link

import android.content.ComponentName
import android.content.ContentValues
import android.content.pm.PackageInfo
import android.content.pm.ProviderInfo
import android.content.pm.Signature
import android.net.Uri
import android.os.Bundle
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.util.Collections
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadow.api.Shadow
import org.robolectric.shadows.ShadowContentProvider
import org.robolectric.shadows.ShadowLog

// AppLinkProvider and AppLinkInbox (contract app-link.md §2, §3.2, §5.3,
// §5.4; D-034; K2-02d): the caller check before anything else, refusals that
// log nothing, backup_now handed to apsira_jobs' RunJobReceiver by an
// explicit in-app broadcast, restore_offer kept in the inbox the app's Dart
// takes, and every entry point but call throwing.
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [SigningShadow::class])
class AppLinkProviderTest {
    private val app = RuntimeEnvironment.getApplication()
    private val pm = app.packageManager

    private fun cert(name: String) = Signature(javaClass.classLoader!!.getResourceAsStream(name)!!.readBytes())

    private val release = cert("release-cert.der")
    private val debug = cert("debug-cert.der")

    private fun hex(signature: Signature): String =
        MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it) }

    private fun install(pkg: String, signature: Signature) {
        @Suppress("DEPRECATION")
        shadowOf(pm).installPackage(PackageInfo().apply {
            packageName = pkg
            signatures = arrayOf(signature)
        })
    }

    private fun trusting(signature: Signature) = FingerprintTable(mapOf(LinkConfig.APSIRA to hex(signature)))

    private fun provider(
        table: FingerprintTable = trusting(release),
        own: String? = null,
        switch: Boolean? = null,
    ): AppLinkProvider = AppLinkProvider(table, own, switch).apply {
        attachInfo(app, ProviderInfo().apply {
            authority = app.packageName + AppLinkProvider.AUTHORITY_SUFFIX
            packageName = app.packageName
            name = AppLinkProvider::class.java.name
            exported = true
        })
    }

    private fun AppLinkProvider.from(caller: String?): AppLinkProvider = apply {
        Shadow.extract<ShadowContentProvider>(this).setCallingPackage(caller)
    }

    private fun extras(vararg pairs: Pair<String, Any?>): Bundle = Bundle().apply {
        putString("contract", LinkConfig.CONTRACT)
        putString("version", "1.0")
        for ((key, value) in pairs) {
            when (value) {
                is String -> putString(key, value)
                is Long -> putLong(key, value)
                is Int -> putInt(key, value)
                null -> putString(key, null)
            }
        }
    }

    private val offer = arrayOf<Pair<String, Any?>>(
        "name" to "relay-2026-10-31T120000Z.bak",
        "snapshot" to "s-41",
        "made_utc" to "2026-10-31T12:00:00Z",
        "size" to 4096L,
        "reason" to "new_device",
    )

    private fun inbox() = File(app.noBackupFilesDir, "${AppLinkInbox.DIR}/${AppLinkInbox.FILE}")

    private fun backupJob(job: String?) {
        shadowOf(pm).getInternalMutablePackageInfo(app.packageName).applicationInfo!!.metaData =
            Bundle().apply { if (job != null) putString(AppLinkProvider.BACKUP_JOB, job) }
    }

    private fun receiver() {
        shadowOf(pm).addReceiverIfNotPresent(ComponentName(app.packageName, AppLinkProvider.RUN_JOB_RECEIVER))
    }

    private fun broadcasts() = shadowOf(app).broadcastIntents

    private fun error(reply: Bundle): String? = reply.getString(AppLinkProvider.ERROR)

    private val listeners = mutableListOf<() -> Unit>()

    @After
    fun tearDown() {
        listeners.forEach { AppLinkInbox.removeListener(it) }
    }

    // The caller check (§3.2): before anything, every call; nothing logged.

    @Test
    fun refusesAnUnknownPackageAWrongCertificateADebugCertificateAndADevCallerInRelease() {
        install("com.example.other", release)
        val other = provider().from("com.example.other").call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        assertEquals(AppLinkProvider.NOT_AUTHORISED, error(other))

        install(LinkConfig.APSIRA, debug)
        val wrong = provider(trusting(release)).from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        assertEquals(AppLinkProvider.NOT_AUTHORISED, error(wrong))

        // The debug certificate is refused even when the table records it (D-031).
        val debugSigned = provider(trusting(debug)).from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        assertEquals(AppLinkProvider.NOT_AUTHORISED, error(debugSigned))

        install(LinkConfig.APSIRA_DEV, release)
        val dev = provider(FingerprintTable(mapOf(LinkConfig.APSIRA_DEV to hex(release))))
            .from(LinkConfig.APSIRA_DEV).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        assertEquals(AppLinkProvider.NOT_AUTHORISED, error(dev))

        val nobody = provider().from(null).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        assertEquals(AppLinkProvider.NOT_AUTHORISED, error(nobody))

        for (reply in listOf(other, wrong, debugSigned, dev, nobody)) assertEquals(setOf(AppLinkProvider.ERROR), reply.keySet())
        assertFalse("a refused offer is never kept", inbox().exists())
    }

    @Test
    fun aRefusalLogsNothing() {
        ShadowLog.clear()
        install("com.example.other", release)
        provider().from("com.example.other").call(AppLinkProvider.BACKUP_NOW, null, extras("reason" to "schedule"))
        provider().from(null).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        assertEquals(emptyList<Any>(), ShadowLog.getLogs().filter { "com.example.other" in it.msg.orEmpty() || it.tag?.contains("apsira", true) == true })
    }

    @Test
    fun theDefaultTableTrustsNoApsiraInRelease() {
        install(LinkConfig.APSIRA, release)
        val reply = AppLinkProvider().apply {
            attachInfo(app, ProviderInfo().apply {
                authority = app.packageName + AppLinkProvider.AUTHORITY_SUFFIX
                packageName = app.packageName
                name = AppLinkProvider::class.java.name
                exported = true
            })
        }.from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        assertEquals(AppLinkProvider.NOT_AUTHORISED, error(reply))
    }

    @Test
    fun acceptsApsiraSignedWithTheRecordedCertificate() {
        install(LinkConfig.APSIRA, release)
        val reply = provider().from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        assertNull(error(reply))
        assertTrue(reply.getBoolean(AppLinkProvider.ACCEPTED))
    }

    @Test
    fun aDevBuildAcceptsOnlyApsiraDevByName() {
        install(LinkConfig.APSIRA_DEV, debug)
        install(LinkConfig.APSIRA, release)
        val dev = provider(own = "com.apsiralabs.relay.dev", switch = true)
        assertTrue(dev.from(LinkConfig.APSIRA_DEV).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer)).getBoolean(AppLinkProvider.ACCEPTED))
        assertEquals(AppLinkProvider.NOT_AUTHORISED, error(dev.from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))))
        // Either condition alone is a release build.
        val idOnly = provider(own = "com.apsiralabs.relay.dev", switch = false)
        assertEquals(AppLinkProvider.NOT_AUTHORISED, error(idOnly.from(LinkConfig.APSIRA_DEV).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))))
    }

    @Test
    fun aWrongContractOrMajorIsUnsupportedVersionAfterTheCheck() {
        install(LinkConfig.APSIRA, release)
        val p = provider().from(LinkConfig.APSIRA)
        val wrongContract = extras(*offer).apply { putString("contract", "other") }
        val wrongMajor = extras(*offer).apply { putString("version", "2.0") }
        val noVersion = extras(*offer).apply { remove("version") }
        for (args in listOf(wrongContract, wrongMajor, noVersion, null)) {
            assertEquals(AppLinkProvider.UNSUPPORTED_VERSION, error(p.call(AppLinkProvider.RESTORE_OFFER, null, args)))
        }
        assertEquals(AppLinkProvider.UNSUPPORTED_VERSION, error(p.call("unknown_method", null, extras())))
        assertTrue(p.call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer).apply { putString("version", "1.7") }).getBoolean(AppLinkProvider.ACCEPTED))
    }

    // backup_now (§5.3): the app's own job, through apsira_jobs, when both ends are there.

    @Test
    fun backupNowSendsTheJobToRunJobReceiverWhenTheMetaDataAndTheReceiverAreThere() {
        install(LinkConfig.APSIRA, release)
        backupJob("appBackup")
        receiver()
        val reply = provider().from(LinkConfig.APSIRA).call(AppLinkProvider.BACKUP_NOW, null, extras("reason" to "schedule"))
        assertTrue(reply.getBoolean(AppLinkProvider.ACCEPTED))
        val sent = broadcasts().single()
        assertEquals(ComponentName(app.packageName, AppLinkProvider.RUN_JOB_RECEIVER), sent.component)
        assertEquals(app.packageName, sent.`package`)
        assertEquals("appBackup", sent.getStringExtra(AppLinkProvider.JOB))
    }

    @Test
    fun backupNowIsNotAcceptedWithoutTheMetaData() {
        install(LinkConfig.APSIRA, release)
        receiver()
        backupJob(null)
        assertFalse(provider().from(LinkConfig.APSIRA).call(AppLinkProvider.BACKUP_NOW, null, extras("reason" to "schedule")).getBoolean(AppLinkProvider.ACCEPTED, true))
        backupJob("")
        assertFalse(provider().from(LinkConfig.APSIRA).call(AppLinkProvider.BACKUP_NOW, null, extras("reason" to "schedule")).getBoolean(AppLinkProvider.ACCEPTED, true))
        assertEquals(0, broadcasts().size)
    }

    @Test
    fun backupNowIsNotAcceptedWhenRunJobReceiverDoesNotResolve() {
        install(LinkConfig.APSIRA, release)
        backupJob("appBackup")
        val reply = provider().from(LinkConfig.APSIRA).call(AppLinkProvider.BACKUP_NOW, null, extras("reason" to "schedule"))
        assertFalse(reply.getBoolean(AppLinkProvider.ACCEPTED, true))
        assertEquals(0, broadcasts().size)
    }

    @Test
    fun backupNowFromARefusedCallerSendsNothing() {
        install("com.example.other", release)
        backupJob("appBackup")
        receiver()
        assertEquals(AppLinkProvider.NOT_AUTHORISED, error(provider().from("com.example.other").call(AppLinkProvider.BACKUP_NOW, null, extras("reason" to "schedule"))))
        assertEquals(0, broadcasts().size)
    }

    // restore_offer (§5.4): kept in the inbox, newest wins, pushed to an engine.

    @Test
    fun restoreOfferIsWrittenAtomicallyAndANewerReplacesAnOlder() {
        install(LinkConfig.APSIRA, release)
        val p = provider().from(LinkConfig.APSIRA)
        assertTrue(p.call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer)).getBoolean(AppLinkProvider.ACCEPTED))
        assertTrue(inbox().exists())
        assertFalse("no temporary file is left", File(inbox().path + ".tmp").exists())
        val newer = extras(*offer).apply {
            putString("snapshot", "s-42")
            putString("reason", "user")
            putInt("size", 10)
        }
        assertTrue(p.call(AppLinkProvider.RESTORE_OFFER, null, newer).getBoolean(AppLinkProvider.ACCEPTED))
        val taken = AppLinkInbox.take(app)!!
        assertEquals("s-42", taken["snapshot"])
        assertEquals("user", taken["reason"])
        assertEquals(10L, taken["size"])
        assertEquals("relay-2026-10-31T120000Z.bak", taken["name"])
        assertEquals("2026-10-31T12:00:00Z", taken["made_utc"])
    }

    @Test
    fun takeReadsAndClears() {
        install(LinkConfig.APSIRA, release)
        assertNull(AppLinkInbox.take(app))
        provider().from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        assertEquals("s-41", AppLinkInbox.take(app)!!["snapshot"])
        assertFalse(inbox().exists())
        assertNull(AppLinkInbox.take(app))
    }

    @Test
    fun aCorruptInboxIsNoOfferAndIsCleared() {
        inbox().parentFile!!.mkdirs()
        inbox().writeText("{not json")
        assertNull(AppLinkInbox.take(app))
        assertFalse(inbox().exists())
    }

    @Test
    fun aMalformedOfferIsNotFoundAndKeepsTheOlderOne() {
        install(LinkConfig.APSIRA, release)
        val p = provider().from(LinkConfig.APSIRA)
        p.call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        val malformed = listOf(
            extras(*offer).apply { remove("name") },
            extras(*offer).apply { putString("name", "") },
            extras(*offer).apply { remove("snapshot") },
            extras(*offer).apply { putString("made_utc", "yesterday") },
            extras(*offer).apply { putString("made_utc", "2026-10-31T12:00:00+01:00") },
            extras(*offer).apply { putLong("size", -1L) },
            extras(*offer).apply { putString("size", "4096") },
            extras(*offer).apply { putString("reason", "schedule") },
            extras(*offer).apply { remove("reason") },
        )
        for (args in malformed) assertEquals(AppLinkProvider.NOT_FOUND, error(p.call(AppLinkProvider.RESTORE_OFFER, null, args)))
        assertEquals("s-41", AppLinkInbox.take(app)!!["snapshot"])
    }

    @Test
    fun anAcceptedOfferIsPushedToEveryAttachedEngine() {
        install(LinkConfig.APSIRA, release)
        var pushed = 0
        val listener = { pushed++; Unit }
        listeners += listener
        AppLinkInbox.addListener(listener)
        provider().from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        assertEquals(1, pushed)
        provider().from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer).apply { remove("name") })
        assertEquals("a malformed offer is not pushed", 1, pushed)
    }

    // The plugin's requests channel: take on a background thread, offer pushed on the main thread.

    private class Messenger : BinaryMessenger {
        val sent: MutableList<Pair<String, String>> = Collections.synchronizedList(mutableListOf())
        val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler?>()

        override fun send(channel: String, message: ByteBuffer?) = send(channel, message, null)
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
            message?.rewind()
            sent += channel to StandardMethodCodec.INSTANCE.decodeMethodCall(message!!).method
        }
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            handlers[channel] = handler
        }
    }

    @Test
    fun thePluginPushesAnOfferOnTheRequestsChannelAndStopsOnDetach() {
        install(LinkConfig.APSIRA, release)
        val messenger = Messenger()
        val plugin = ApsiraLinkPlugin()
        plugin.attach(app, messenger)
        assertTrue(messenger.handlers[ApsiraLinkPlugin.REQUESTS_CHANNEL] != null)
        provider().from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(ApsiraLinkPlugin.REQUESTS_CHANNEL to ApsiraLinkPlugin.OFFER), messenger.sent.toList())
        plugin.detach()
        provider().from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(1, messenger.sent.size)
        assertNull(messenger.handlers[ApsiraLinkPlugin.REQUESTS_CHANNEL])
    }

    @Test
    fun thePluginTakesThePendingOfferOffTheMainThread() {
        install(LinkConfig.APSIRA, release)
        provider().from(LinkConfig.APSIRA).call(AppLinkProvider.RESTORE_OFFER, null, extras(*offer))
        val messenger = Messenger()
        val plugin = ApsiraLinkPlugin()
        plugin.attach(app, messenger)
        try {
            val replies = Collections.synchronizedList(mutableListOf<Any?>())
            val take = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(ApsiraLinkPlugin.TAKE, null)).apply { rewind() }
            messenger.handlers[ApsiraLinkPlugin.REQUESTS_CHANNEL]!!.onMessage(take) { reply ->
                reply!!.rewind()
                replies += StandardMethodCodec.INSTANCE.decodeEnvelope(reply)
            }
            val deadline = System.currentTimeMillis() + 5_000
            while (replies.isEmpty() && System.currentTimeMillis() < deadline) {
                shadowOf(Looper.getMainLooper()).idle()
                Thread.sleep(10)
            }
            val taken = replies.single() as Map<*, *>
            assertEquals("s-41", taken["snapshot"])
            assertEquals(4096L, (taken["size"] as Number).toLong())
            assertFalse(inbox().exists())
        } finally {
            plugin.detach()
        }
    }

    // Every other entry point (§2).

    @Test
    fun everyEntryPointButCallThrows() {
        val p = provider().from(LinkConfig.APSIRA)
        val uri = Uri.parse("content://${app.packageName}${AppLinkProvider.AUTHORITY_SUFFIX}/x")
        val attempts = listOf<() -> Any?>(
            { p.query(uri, null, null, null, null) },
            { p.insert(uri, ContentValues()) },
            { p.update(uri, ContentValues(), null, null) },
            { p.delete(uri, null, null) },
            { p.openFile(uri, "r") },
        )
        for (attempt in attempts) {
            try {
                attempt()
                fail("an entry point other than call answered")
            } catch (e: UnsupportedOperationException) {
                // expected
            }
        }
    }
}
