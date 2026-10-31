package com.apsiralabs.apsira_link

import android.content.ContentProvider
import android.content.ContentProviderClient
import android.content.ContentResolver
import android.content.ContentValues
import android.content.pm.PackageInfo
import android.content.pm.ProviderInfo
import android.content.pm.Signature
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import java.security.MessageDigest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowContentResolver

/**
 * Runs [afterAcquire] right after LinkClient acquires its provider client,
 * so a test can change APSIRA between the acquire and the check (T1 F-3).
 */
@Implements(ContentResolver::class)
class AcquireShadow : ShadowContentResolver() {
    companion object {
        var afterAcquire: (() -> Unit)? = null
        var acquired: ContentProviderClient? = null
    }

    @Implementation
    override fun acquireUnstableContentProviderClient(name: String): ContentProviderClient? {
        val client = super.acquireUnstableContentProviderClient(name)
        acquired = client
        afterAcquire?.invoke()
        return client
    }
}

// LinkClient (contract app-link.md §2-§4, §8): APSIRA is resolved and
// checked before anything is called, and every failure is a reply, never a
// throw. Providers are registered as ATRIUM's StylusContractTest builds
// them (Robolectric.buildContentProvider), each installed under a package
// signed with a public test certificate.
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [SigningShadow::class])
class LinkClientTest {
    /** APSIRA's stand-in: records each call and answers [reply] or throws [failure]. */
    class FakeApsira : ContentProvider() {
        val calls = mutableListOf<Pair<String, Bundle?>>()
        var reply: Bundle? = null
        var failure: RuntimeException? = null
        var during: (() -> Unit)? = null

        override fun call(method: String, arg: String?, extras: Bundle?): Bundle? {
            calls += method to extras
            during?.invoke()
            failure?.let { throw it }
            return reply
        }

        override fun onCreate() = true
        override fun query(uri: Uri, p: Array<out String>?, s: String?, a: Array<out String>?, o: String?): Cursor? =
            throw UnsupportedOperationException()
        override fun getType(uri: Uri): String? = null
        override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException()
        override fun delete(uri: Uri, s: String?, a: Array<out String>?): Int = throw UnsupportedOperationException()
        override fun update(uri: Uri, v: ContentValues?, s: String?, a: Array<out String>?): Int =
            throw UnsupportedOperationException()
    }

    private val app = RuntimeEnvironment.getApplication()
    private val pm = app.packageManager

    private val relay = "com.apsiralabs.relay"
    private val relayDev = "com.apsiralabs.relay.dev"

    private fun cert(name: String) = Signature(javaClass.classLoader!!.getResourceAsStream(name)!!.readBytes())

    private val release = cert("release-cert.der")
    private val debug = cert("debug-cert.der")

    private fun hex(signature: Signature): String =
        MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it) }

    private val hello = Bundle().apply {
        putStringArray("versions", arrayOf("1.0"))
        putString("app_version", "0.1.0")
        putBoolean("locked", false)
    }

    /** Installs [pkg] signed with [signature], holding a FakeApsira at [authority]. */
    private fun register(pkg: String, authority: String, signature: Signature = release): FakeApsira {
        @Suppress("DEPRECATION")
        shadowOf(pm).installPackage(PackageInfo().apply {
            packageName = pkg
            signatures = arrayOf(signature)
        })
        val info = ProviderInfo().apply {
            this.authority = authority
            packageName = pkg
            name = FakeApsira::class.java.name
            exported = true
        }
        shadowOf(pm).addOrUpdateProvider(info)
        return Robolectric.buildContentProvider(FakeApsira::class.java).create(info).get().apply { reply = hello }
    }

    private fun apsira(signature: Signature = release) = register(LinkConfig.APSIRA, LinkConfig.APSIRA + LinkConfig.AUTHORITY_SUFFIX, signature)

    private fun apsiraDev() = register(LinkConfig.APSIRA_DEV, LinkConfig.APSIRA_DEV + LinkConfig.AUTHORITY_SUFFIX)

    private fun trusting(signature: Signature) = FingerprintTable(mapOf(LinkConfig.APSIRA to hex(signature)))

    private fun client(own: String = relay, switch: Boolean = false, table: FingerprintTable = trusting(release)) =
        LinkClient(app, own, switch, table)

    private fun hello(client: LinkClient) = client.call("hello", "1.0", emptyMap())

    private fun unavailable(reason: String) = mapOf("unavailable" to reason)

    @Test
    fun noApsiraIsNotInstalled() {
        assertEquals(unavailable("not_installed"), hello(client()))
    }

    @Test
    fun theAuthorityUnderAnotherPackageIsNotTrustedAndNeverCalled() {
        val impostor = register("com.apsiralabs.impostor", LinkConfig.APSIRA + LinkConfig.AUTHORITY_SUFFIX)
        assertEquals(unavailable("not_trusted"), hello(client()))
        assertEquals(0, impostor.calls.size)
    }

    @Test
    fun theDefaultTableTrustsNoApsiraAndNothingIsCalled() {
        val provider = apsira()
        assertEquals(unavailable("not_trusted"), hello(LinkClient(app, relay, false)))
        assertEquals(0, provider.calls.size)
    }

    @Test
    fun aTrustedApsiraAnswersWithTheContractAndVersionSent() {
        val provider = apsira()

        val reply = client().call("hello", "1.0", mapOf("x" to "y"))

        assertEquals(false, reply["devUnverified"])
        @Suppress("UNCHECKED_CAST")
        val fields = reply["fields"] as Map<String, Any?>
        assertEquals(listOf("1.0"), fields["versions"])
        assertEquals("0.1.0", fields["app_version"])
        assertEquals(false, fields["locked"])
        assertEquals(1, provider.calls.size)
        val (method, extras) = provider.calls.single()
        assertEquals("hello", method)
        assertEquals(LinkConfig.CONTRACT, extras!!.getString("contract"))
        assertEquals("1.0", extras.getString("version"))
        assertEquals("y", extras.getString("x"))
    }

    @Test
    fun aDebugSubjectApsiraIsNotTrustedEvenWithItsDigestInTheTable() {
        val provider = apsira(debug)
        assertEquals(unavailable("not_trusted"), hello(client(table = trusting(debug))))
        assertEquals(0, provider.calls.size)
    }

    @Test
    fun anApsiraSignedWithAnotherCertificateIsNotTrusted() {
        val provider = apsira(release)
        assertEquals(unavailable("not_trusted"), hello(client(table = trusting(debug))))
        assertEquals(0, provider.calls.size)
    }

    @Test
    fun aDevBuildTalksToTheDevApsiraByNameAndSaysSo() {
        val provider = apsiraDev()

        val reply = hello(client(own = relayDev, switch = true))

        assertEquals(true, reply["devUnverified"])
        @Suppress("UNCHECKED_CAST")
        assertEquals("0.1.0", (reply["fields"] as Map<String, Any?>)["app_version"])
        assertEquals(1, provider.calls.size)
    }

    @Test
    fun aReleaseIdNeverReachesTheDevApsiraSwitchOrNot() {
        val provider = apsiraDev()
        assertEquals(unavailable("not_installed"), hello(client(own = relay, switch = false)))
        assertEquals(unavailable("not_installed"), hello(client(own = relay, switch = true)))
        assertEquals(0, provider.calls.size)
    }

    @Test
    fun aDevIdWithoutTheSwitchNeverReachesTheDevApsira() {
        val provider = apsiraDev()
        assertEquals(unavailable("not_installed"), hello(client(own = relayDev, switch = false)))
        assertEquals(0, provider.calls.size)
    }

    @Test
    fun aDevBuildNeverReachesTheReleaseApsira() {
        val provider = apsira()
        assertEquals(unavailable("not_installed"), hello(client(own = relayDev, switch = true)))
        assertEquals(0, provider.calls.size)
    }

    @Test
    fun anErrorIsPassedOn() {
        apsira().reply = Bundle().apply { putString("error", "busy") }
        assertEquals(mapOf("error" to "busy"), hello(client()))
    }

    @Test
    fun aThrowingProviderAndANullBundleAreNoAnswer() {
        val provider = apsira()
        provider.failure = IllegalStateException("gone")
        assertEquals(unavailable("no_answer"), hello(client()))
        provider.failure = null
        provider.reply = null
        assertEquals(unavailable("no_answer"), hello(client()))
        assertTrue(provider.calls.size == 2)
    }

    @Test
    fun theDefaultsReadTheOwnPackageAndSwitch() {
        apsiraDev()
        // The test app's id does not end in .dev and its manifest has no
        // switch: the release APSIRA is the peer, and it is absent.
        assertEquals(unavailable("not_installed"), hello(LinkClient(app)))
    }

    // T1's F-3 (K2-02a): acquire, then check, then call through what was
    // acquired, then check again.

    /** Installs APSIRA again, now signed with the certificate the table does not hold. */
    private fun replaceApsiraSigner() {
        @Suppress("DEPRECATION")
        shadowOf(pm).installPackage(PackageInfo().apply {
            packageName = LinkConfig.APSIRA
            signatures = arrayOf(debug)
        })
        // The reinstall drops the provider's entry; the new APK declares it again.
        shadowOf(pm).addOrUpdateProvider(ProviderInfo().apply {
            authority = LinkConfig.APSIRA + LinkConfig.AUTHORITY_SUFFIX
            packageName = LinkConfig.APSIRA
            name = FakeApsira::class.java.name
            exported = true
        })
    }

    private fun <T> acquiring(after: () -> Unit, body: () -> T): T {
        AcquireShadow.afterAcquire = after
        try {
            return body()
        } finally {
            AcquireShadow.afterAcquire = null
            AcquireShadow.acquired = null
        }
    }

    @Test
    @Config(shadows = [SigningShadow::class, AcquireShadow::class])
    fun theCallGoesThroughTheClientAcquiredBeforeTheCheckAndReleasesIt() {
        val acquiredApsira = apsira()
        var later: FakeApsira? = null

        val reply = acquiring({ later = apsira() }) {
            hello(client()).also { assertTrue(shadowOf(AcquireShadow.acquired!!).isReleased) }
        }

        assertEquals(false, reply["devUnverified"])
        assertEquals(1, acquiredApsira.calls.size)
        assertEquals(0, later!!.calls.size)
    }

    @Test
    @Config(shadows = [SigningShadow::class, AcquireShadow::class])
    fun aPackageThatChangesBetweenAcquireAndCheckIsNotTrustedAndNothingIsCalled() {
        val provider = apsira()

        val reply = acquiring({ replaceApsiraSigner() }) { hello(client()) }

        assertEquals(unavailable("not_trusted"), reply)
        assertEquals(0, provider.calls.size)
    }

    @Test
    fun aReplyAfterATrustChangeIsDiscardedAndItsStreamsClosed() {
        val pipe = ParcelFileDescriptor.createPipe()
        val streams = LinkStreams()
        val provider = apsira().apply {
            reply = Bundle().apply { putParcelable("fd", pipe[1]) }
            during = { replaceApsiraSigner() }
        }

        val reply = LinkClient(app, relay, false, trusting(release), streams).call("backup_begin", "1.0", emptyMap())

        assertEquals(unavailable("not_trusted"), reply)
        assertEquals(1, provider.calls.size)
        assertEquals(0, streams.openCount)
        assertEquals(-1, ParcelFileDescriptor.AutoCloseInputStream(pipe[0]).read())
    }

    @Test
    fun aDescriptorInAnErrorReplyIsClosed() {
        val pipe = ParcelFileDescriptor.createPipe()
        apsira().reply = Bundle().apply {
            putString("error", "busy")
            putParcelable("fd", pipe[1])
        }
        assertEquals(mapOf("error" to "busy"), hello(client()))
        assertEquals(-1, ParcelFileDescriptor.AutoCloseInputStream(pipe[0]).read())
    }

    @Test
    fun aDescriptorInAnAnswerReachesDartAsAStreamHandle() {
        val pipe = ParcelFileDescriptor.createPipe()
        val streams = LinkStreams()
        apsira().reply = Bundle().apply {
            putParcelable("fd", pipe[1])
            putString("ticket", "t-1")
        }

        val reply = LinkClient(app, relay, false, trusting(release), streams).call("backup_begin", "1.0", emptyMap())

        @Suppress("UNCHECKED_CAST")
        val fields = reply["fields"] as Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val handle = (fields["fd"] as Map<String, Any?>)[LinkStreams.STREAM] as Int
        assertEquals("t-1", fields["ticket"])
        assertEquals(1, streams.openCount)
        assertEquals(emptyMap<String, Any?>(), streams.write(handle, byteArrayOf(9)))
        streams.closeAll()
    }
}
