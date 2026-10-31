package com.apsiralabs.apsira_link

import android.content.pm.PackageInfo
import android.content.pm.Signature
import android.os.Bundle
import java.security.MessageDigest
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

// LinkTrust.kt (contract app-link.md §3, D-031, rulings R-2 and R-5): the
// fingerprint table, the certificate trust with its debug-subject and
// API 28 refusals, the caller check APSIRA's provider uses, and the dev
// selection, which needs both an own id ending in .dev and the DEV_LINK
// switch. The certificates are public test ones (src/test/resources):
// release-cert.der is CN=Apsira Test, debug-cert.der the SDK debug subject.
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [SigningShadow::class])
class LinkTrustTest {
    private val app = RuntimeEnvironment.getApplication()
    private val pm = app.packageManager

    private val apsira = LinkConfig.APSIRA
    private val apsiraDev = LinkConfig.APSIRA_DEV
    private val relay = "com.apsiralabs.relay"
    private val relayDev = "com.apsiralabs.relay.dev"

    private fun cert(name: String) = Signature(javaClass.classLoader!!.getResourceAsStream(name)!!.readBytes())

    private val release = cert("release-cert.der")
    private val debug = cert("debug-cert.der")

    private fun sha(signature: Signature): ByteArray = MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())

    private fun hex(signature: Signature): String = sha(signature).joinToString("") { "%02x".format(it) }

    private fun install(pkg: String, signature: Signature) {
        @Suppress("DEPRECATION")
        val info = PackageInfo().apply {
            packageName = pkg
            signatures = arrayOf(signature)
        }
        shadowOf(pm).installPackage(info)
    }

    private fun table(vararg entries: Pair<String, Signature>) =
        FingerprintTable(entries.associate { (pkg, sig) -> pkg to hex(sig) })

    // The configuration (§3.1, ruling A-7).

    @Test
    fun fApsiraIsNotRecordedSoTheDefaultTableTrustsNoApsira() {
        assertEquals("", LinkConfig.F_APSIRA)
        assertNull(LinkTrust.apsiraTable.digest(apsira))
        assertEquals(setOf(apsira), LinkTrust.apsiraTable.packages)
        install(apsira, release)
        assertFalse(LinkTrust.forPeer(relay, false).trusts(pm, apsira))
    }

    @Test
    fun theNamesAreTheContracts() {
        assertEquals("com.apsiralabs.apsira", LinkConfig.APSIRA)
        assertEquals("com.apsiralabs.apsira.dev", LinkConfig.APSIRA_DEV)
        assertEquals(".link", LinkConfig.AUTHORITY_SUFFIX)
        assertEquals("apsira.app_link", LinkConfig.CONTRACT)
        assertEquals("com.apsiralabs.apsira_link.DEV_LINK", LinkConfig.DEV_SWITCH)
    }

    // The table.

    @Test
    fun aDigestIsSixtyFourHexDigitsColonsAndUpperCaseAllowed() {
        val plain = hex(release)
        val colons = plain.uppercase().chunked(2).joinToString(":")
        val t = FingerprintTable(mapOf("a" to plain, "b" to colons))
        assertArrayEquals(sha(release), t.digest("a"))
        assertArrayEquals(sha(release), t.digest("b"))
        assertEquals(setOf("a", "b"), t.packages)
    }

    @Test
    fun aMalformedOrUnrecordedDigestIsNone() {
        val t = FingerprintTable(
            mapOf("short" to hex(release).dropLast(1), "empty" to "", "pending" to "NOT-YET-RECORDED", "long" to hex(release) + "0"),
        )
        for (pkg in listOf("short", "empty", "pending", "long", "absent")) assertNull(pkg, t.digest(pkg))
    }

    // CertificateTrust (§3.2, D-031).

    @Test
    fun aCertificateTrustTrustsAPackageSignedWithItsRecordedCertificate() {
        install(apsira, release)
        val trust = CertificateTrust(table(apsira to release))
        assertTrue(trust.trusts(pm, apsira))
        assertFalse(trust.devUnverified)
    }

    @Test
    fun aCertificateTrustRefusesEveryDevPackageEvenRecordedAndSigned() {
        install(apsiraDev, release)
        install(relayDev, release)
        val trust = CertificateTrust(table(apsiraDev to release, relayDev to release))
        assertFalse(trust.trusts(pm, apsiraDev))
        assertFalse(trust.trusts(pm, relayDev))
    }

    @Test
    fun belowApi28NothingIsTrusted() {
        install(apsira, release)
        assertFalse(CertificateTrust(table(apsira to release), sdkInt = 27).trusts(pm, apsira))
        assertTrue(CertificateTrust(table(apsira to release), sdkInt = 28).trusts(pm, apsira))
    }

    @Test
    fun anUnrecordedDigestTrustsNoOne() {
        install(apsira, release)
        assertFalse(CertificateTrust(FingerprintTable(mapOf(apsira to ""))).trusts(pm, apsira))
        assertFalse(CertificateTrust(table(relay to release)).trusts(pm, apsira))
    }

    @Test
    fun aDebugSubjectSignerIsRefusedEvenWhenItsDigestIsInTheTable() {
        install(apsira, debug)
        assertFalse(CertificateTrust(table(apsira to debug)).trusts(pm, apsira))
    }

    @Test
    fun aPackageSignedWithAnotherCertificateIsRefused() {
        install(apsira, release)
        assertFalse(CertificateTrust(table(apsira to debug)).trusts(pm, apsira))
    }

    @Test
    fun aPackageNotInstalledIsRefused() {
        assertFalse(CertificateTrust(table(apsira to release)).trusts(pm, apsira))
    }

    // CallerCheck (§3.2, the provider side).

    @Test
    fun theCallerCheckAllowsOnlyATableCallerSignedWithItsCertificate() {
        install(relay, release)
        install("com.apsiralabs.other", release)
        install("com.apsiralabs.atrium", release)
        val trust = CertificateTrust(table(relay to release, "com.apsiralabs.atrium" to debug))
        assertTrue(CallerCheck.allows(pm, relay, trust))
        assertFalse(CallerCheck.allows(pm, null, trust))
        assertFalse(CallerCheck.allows(pm, "com.apsiralabs.other", trust))
        assertFalse(CallerCheck.allows(pm, "com.apsiralabs.atrium", trust))
    }

    // The dev selection (§3.3, R-2): both conditions, never one.

    @Test
    fun aDevBuildIsAnOwnDevIdWithTheSwitchOn() {
        assertTrue(LinkTrust.isDevBuild(relayDev, true))
        assertFalse(LinkTrust.isDevBuild(relayDev, false))
        assertFalse(LinkTrust.isDevBuild(relay, true))
        assertFalse(LinkTrust.isDevBuild(relay, false))
        assertEquals(apsiraDev, LinkTrust.peer(relayDev, true))
        for ((own, switch) in listOf(relayDev to false, relay to true, relay to false)) {
            assertEquals("$own $switch", apsira, LinkTrust.peer(own, switch))
        }
    }

    private fun assertRefusesEveryDevPackage(trust: Trust) {
        for (pkg in listOf(apsiraDev, relayDev, "com.apsiralabs.atrium.dev")) {
            install(pkg, release)
            assertFalse(pkg, trust.trusts(pm, pkg))
        }
    }

    private val devTable get() = table(
        apsira to release, apsiraDev to release, relay to release, relayDev to release, "com.apsiralabs.atrium.dev" to release,
    )

    @Test
    fun aDevBuildTrustsTheDevApsiraByNameOnly() {
        val trust = LinkTrust.forPeer(relayDev, true, devTable)
        assertTrue(trust is DevNameTrust)
        assertTrue(trust.devUnverified)
        assertTrue(trust.trusts(pm, apsiraDev))
        install(apsira, release)
        for (pkg in listOf(apsira, relay, relayDev, "$apsiraDev.x")) assertFalse(pkg, trust.trusts(pm, pkg))
    }

    @Test
    fun eitherConditionAloneSelectsTheCertificateTrustForThePeer() {
        for ((own, switch) in listOf(relay to false, relay to true, relayDev to false)) {
            val trust = LinkTrust.forPeer(own, switch, devTable)
            assertTrue("$own $switch", trust is CertificateTrust)
            assertFalse(trust.devUnverified)
            assertRefusesEveryDevPackage(trust)
        }
    }

    @Test
    fun aDevApsiraTrustsTheTablesDevCallersByNameOnly() {
        val trust = LinkTrust.forCallers(apsiraDev, true, table(relay to release, "com.apsiralabs.atrium" to release))
        assertTrue(trust is DevNameTrust)
        assertTrue(trust.devUnverified)
        assertTrue(CallerCheck.allows(pm, relayDev, trust))
        assertTrue(CallerCheck.allows(pm, "com.apsiralabs.atrium.dev", trust))
        for (pkg in listOf(relay, "com.apsiralabs.viaticum.dev", apsiraDev, null)) {
            assertFalse("$pkg", CallerCheck.allows(pm, pkg, trust))
        }
    }

    @Test
    fun eitherConditionAloneSelectsTheCertificateTrustForCallers() {
        for ((own, switch) in listOf(apsira to false, apsira to true, apsiraDev to false)) {
            val trust = LinkTrust.forCallers(own, switch, devTable)
            assertTrue("$own $switch", trust is CertificateTrust)
            assertRefusesEveryDevPackage(trust)
        }
    }

    // The switch reader: the app's own ApplicationInfo.

    private fun ownMetaData(bundle: Bundle?) {
        shadowOf(pm).getInternalMutablePackageInfo(app.packageName).applicationInfo!!.metaData = bundle
    }

    @Test
    fun theSwitchIsReadFromTheOwnManifestsMetaData() {
        ownMetaData(Bundle().apply { putBoolean(LinkConfig.DEV_SWITCH, true) })
        assertTrue(LinkTrust.devSwitchOn(app))
        ownMetaData(Bundle().apply { putBoolean(LinkConfig.DEV_SWITCH, false) })
        assertFalse(LinkTrust.devSwitchOn(app))
        ownMetaData(Bundle().apply { putBoolean("other", true) })
        assertFalse(LinkTrust.devSwitchOn(app))
        ownMetaData(null)
        assertFalse(LinkTrust.devSwitchOn(app))
    }

    @Test
    fun theLibrarysOwnManifestCarriesNoSwitch() {
        assertFalse(LinkTrust.devSwitchOn(app))
    }
}
