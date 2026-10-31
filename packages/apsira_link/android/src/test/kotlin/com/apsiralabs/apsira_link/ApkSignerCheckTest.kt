package com.apsiralabs.apsira_link

import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.content.pm.SigningInfo
import java.security.MessageDigest
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.shadow.api.Shadow
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowSigningInfo

// ApkSignerCheck.kt: an APK file is trusted only when Android reads its
// archive info (API 28+), it has exactly one current signer, its package is
// in the table, the signer is not the SDK debug certificate and its SHA-256
// is the recorded one. The certificates are T1's public test ones
// (src/test/resources): release-cert.der is CN=Apsira Test, debug-cert.der
// the SDK debug subject. The archive path runs on Robolectric's archive info
// (ShadowPackageManager.setPackageArchiveInfo); the decision is checkSigners.
@RunWith(RobolectricTestRunner::class)
class ApkSignerCheckTest {
    private val pm: PackageManager = RuntimeEnvironment.getApplication().packageManager

    private val relay = "com.apsiralabs.relay"
    private val apk = "/scratch/relay.apk"

    private fun cert(name: String) = Signature(javaClass.classLoader!!.getResourceAsStream(name)!!.readBytes())

    private val release = cert("release-cert.der")
    private val debug = cert("debug-cert.der")

    private fun hex(signature: Signature): String =
        MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it) }

    private fun table(vararg entries: Pair<String, Signature>) =
        FingerprintTable(entries.associate { (pkg, sig) -> pkg to hex(sig) })

    private fun archive(pkg: String, vararg signers: Signature, version: Long = 42) {
        val signing = Shadow.newInstanceOf(SigningInfo::class.java)
        Shadow.extract<ShadowSigningInfo>(signing).setSignatures(arrayOf(*signers))
        val info = PackageInfo().apply {
            packageName = pkg
            longVersionCode = version
            signingInfo = signing
        }
        shadowOf(pm).setPackageArchiveInfo(apk, info)
    }

    private fun refused(reason: String) = ApkVerdict.Refused(reason)

    @Test
    fun oneReleaseSignerWithItsRecordedDigestIsTrusted() {
        archive(relay, release, version = 7)
        assertEquals(ApkVerdict.Trusted(relay, 7), ApkSignerCheck.check(pm, apk, table(relay to release)))
    }

    @Test
    fun aSignerOtherThanTheRecordedOneIsRefusedDigest() {
        archive(relay, release)
        val other = FingerprintTable(mapOf(relay to "ab".repeat(32)))
        assertEquals(refused("digest"), ApkSignerCheck.check(pm, apk, other))
    }

    @Test
    fun theSdkDebugSubjectIsRefusedDebugEvenWhenItsDigestIsRecorded() {
        archive(relay, debug)
        assertEquals(refused("debug"), ApkSignerCheck.check(pm, apk, table(relay to debug)))
    }

    @Test
    fun twoSignersAreRefusedSigners() {
        archive(relay, release, release)
        assertEquals(refused("signers"), ApkSignerCheck.check(pm, apk, table(relay to release)))
    }

    @Test
    fun noSigningInfoIsRefusedSigners() {
        shadowOf(pm).setPackageArchiveInfo(apk, PackageInfo().apply { packageName = relay })
        assertEquals(refused("signers"), ApkSignerCheck.check(pm, apk, table(relay to release)))
    }

    @Test
    fun aPackageNotInTheTableIsRefusedUnrecorded() {
        archive("com.apsiralabs.viaticum", release)
        assertEquals(refused("unrecorded"), ApkSignerCheck.check(pm, apk, table(relay to release)))
    }

    @Test
    fun aMalformedRecordedDigestIsRefusedUnrecorded() {
        archive(relay, release)
        assertEquals(refused("unrecorded"), ApkSignerCheck.check(pm, apk, FingerprintTable(mapOf(relay to "nope"))))
    }

    @Test
    fun aPathWithNoArchiveInfoIsRefusedUnreadable() {
        assertEquals(refused("unreadable"), ApkSignerCheck.check(pm, "/scratch/missing.apk", table(relay to release)))
    }

    @Test
    fun belowApi28NothingIsTrusted() {
        archive(relay, release)
        assertEquals(refused("api"), ApkSignerCheck.check(pm, apk, table(relay to release), sdkInt = 27))
    }

    // The pure decision, without the package manager.

    @Test
    fun checkSignersRefusesEachCaseWithoutThePackageManager() {
        val digest = FingerprintTable(mapOf(relay to hex(release))).digest(relay)
        assertEquals(null, ApkSignerCheck.checkSigners(listOf(release), multiple = false, digest = digest))
        assertEquals("signers", ApkSignerCheck.checkSigners(emptyList(), multiple = false, digest = digest))
        assertEquals("signers", ApkSignerCheck.checkSigners(listOf(release), multiple = true, digest = digest))
        assertEquals("unrecorded", ApkSignerCheck.checkSigners(listOf(release), multiple = false, digest = null))
        assertEquals("debug", ApkSignerCheck.checkSigners(listOf(debug), multiple = false, digest = digest))
        assertEquals("debug", ApkSignerCheck.checkSigners(listOf(Signature(byteArrayOf(1, 2, 3))), multiple = false, digest = digest))
    }
}
