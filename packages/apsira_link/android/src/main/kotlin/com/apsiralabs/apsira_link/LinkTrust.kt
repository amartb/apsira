// From atrium android/app/src/main/kotlin/com/apsiralabs/atrium/files/CallerCheck.kt @ 1ce8ec8
package com.apsiralabs.apsira_link

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import java.io.ByteArrayInputStream
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate

// Who is trusted on the APSIRA app link (contract app-link.md §3, D-016,
// D-031), the KAIROS pattern ATRIUM's CallerCheck.kt implements, re-homed
// for both sides: the app checks APSIRA before calling (LinkClient), and
// APSIRA's provider checks its caller on every call (CallerCheck). There is
// no permission layer: every app signs with its own key.
//
// Changes from ATRIUM's file (recorded in D-APK-026's addendum):
// - a FingerprintTable of package → digest in place of one Pairing's peer
//   and digest, so APSIRA checks every app in its table and an app its one
//   peer through the same type;
// - a signer whose subject is the SDK debug one (CN=Android Debug) is
//   refused even when its digest is in the table (D-031: "in the table or
//   anywhere else"), and no .dev package is ever certificate-trusted;
// - below API 28 (no hasSigningCertificate) nothing is trusted, so Android
//   7-8 never gets a false trust;
// - the relaxed dev check is selected at run time by two conditions, the
//   app's own id ending in .dev and the DEV_LINK meta-data its dev source
//   set declares (rulings R-2, R-5), in place of ATRIUM's src/dev and
//   src/prod flavours, which a package does not have.

/** The link's fixed names (contract §2, §3.1, §4; ruling R-2). */
object LinkConfig {
    /**
     * The SHA-256 of APSIRA's release certificate: not recorded until
     * APSIRA's release-signing.md §2 records it (contract §3.1, ruling A-7),
     * so a release app trusts no APSIRA yet.
     */
    const val F_APSIRA = ""

    const val APSIRA = "com.apsiralabs.apsira"
    const val APSIRA_DEV = "com.apsiralabs.apsira.dev"

    /** APSIRA's authority is its package + this. */
    const val AUTHORITY_SUFFIX = ".link"

    /** The `contract` extra every call carries. */
    const val CONTRACT = "apsira.app_link"

    /** The meta-data an app declares in its dev source set only (Dart `linkDevSwitch`). */
    const val DEV_SWITCH = "com.apsiralabs.apsira_link.DEV_LINK"
}

/**
 * Package → SHA-256 of its release certificate: 64 hex digits, colons
 * allowed. A malformed or empty value is no digest, so it trusts no one.
 */
class FingerprintTable(entries: Map<String, String>) {
    private val digests: Map<String, ByteArray?> = entries.mapValues { (_, hex) -> parse(hex) }

    /** Every package named, recorded or not. */
    val packages: Set<String> = entries.keys.toSet()

    /** [pkg]'s digest; null when unrecorded or malformed. */
    fun digest(pkg: String): ByteArray? = digests[pkg]?.copyOf()

    private companion object {
        private val HEX = Regex("[0-9A-Fa-f]{64}")

        fun parse(hex: String): ByteArray? {
            val digits = hex.replace(":", "")
            if (!HEX.matches(digits)) return null
            return ByteArray(32) { digits.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
        }
    }
}

/** How a peer or a caller is trusted. */
interface Trust {
    /** Whether [pkg] is trusted, checked now (never cached). */
    fun trusts(pm: PackageManager, pkg: String): Boolean

    /** Whether the trust is by package name only (a dev link, contract §3.3). */
    val devUnverified: Boolean
}

/**
 * Trusts a package of [table] when Android confirms it is signed with its
 * recorded certificate and no signer is the SDK debug certificate. Never a
 * .dev package, never below API 28; any failure is "not trusted".
 */
class CertificateTrust(
    private val table: FingerprintTable,
    private val sdkInt: Int = Build.VERSION.SDK_INT,
) : Trust {
    override val devUnverified = false

    // hasSigningCertificate and GET_SIGNING_CERTIFICATES are API 28: the
    // sdkInt check comes first.
    @SuppressLint("NewApi")
    override fun trusts(pm: PackageManager, pkg: String): Boolean {
        if (sdkInt < Build.VERSION_CODES.P) return false
        if (pkg.endsWith(DEV)) return false
        val digest = table.digest(pkg) ?: return false
        return try {
            pm.hasSigningCertificate(pkg, digest, PackageManager.CERT_INPUT_SHA256) && !debugSigned(pm, pkg)
        } catch (e: RuntimeException) {
            false
        }
    }

    // True when any signer is the SDK debug certificate, or when the signers
    // cannot be read or parsed: an unreadable signer is never trusted.
    @SuppressLint("NewApi")
    private fun debugSigned(pm: PackageManager, pkg: String): Boolean {
        val signers = try {
            @Suppress("DEPRECATION")
            val info = pm.getPackageInfo(pkg, PackageManager.GET_SIGNATURES or PackageManager.GET_SIGNING_CERTIFICATES)
            val current = info.signingInfo?.let { if (it.hasMultipleSigners()) it.apkContentsSigners else it.signingCertificateHistory }
            @Suppress("DEPRECATION")
            (current.orEmpty().toList() + info.signatures.orEmpty().toList())
        } catch (e: Exception) {
            return true
        }
        if (signers.isEmpty()) return true
        return signers.any { isDebugSubject(it) }
    }

    private companion object {
        const val DEV = ".dev"
    }
}

/** The SDK debug certificate's common name (CN=Android Debug,O=Android,C=US). */
private const val DEBUG_CN = "CN=Android Debug"

/** RFC 2253 separates RDNs by unescaped commas. */
private val RDN_SEPARATOR = Regex("(?<!\\\\)[,+]")

/**
 * Whether [signature]'s subject has the SDK debug common name, or does not
 * parse: an unparseable signer is never trusted. [CertificateTrust] and
 * [ApkSignerCheck] both refuse on it.
 */
internal fun isDebugSubject(signature: Signature): Boolean {
    val subject = try {
        val cert = CertificateFactory.getInstance("X.509")
            .generateCertificate(ByteArrayInputStream(signature.toByteArray())) as X509Certificate
        cert.subjectX500Principal.name
    } catch (e: Exception) {
        return true
    }
    return subject.split(RDN_SEPARATOR).any { it.trim().equals(DEBUG_CN, ignoreCase = true) }
}

/**
 * A dev build's trust (contract §3.3): only the listed packages, and only
 * those ending in .dev, by name; every answer is "dev link: unverified".
 */
class DevNameTrust(packages: Set<String>) : Trust {
    private val packages: Set<String> = packages.filter { it.endsWith(".dev") }.toSet()

    override val devUnverified = true

    override fun trusts(pm: PackageManager, pkg: String): Boolean = pkg in packages
}

/** Which trust a build uses: the dev selection needs both conditions (ruling R-2). */
object LinkTrust {
    /** The table an app checks APSIRA against: APSIRA → [LinkConfig.F_APSIRA]. */
    val apsiraTable = FingerprintTable(mapOf(LinkConfig.APSIRA to LinkConfig.F_APSIRA))

    /**
     * Whether the app's own merged manifest carries the DEV_LINK switch with
     * value true. Any failure reads as off.
     */
    fun devSwitchOn(context: Context): Boolean = try {
        context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            .metaData?.getBoolean(LinkConfig.DEV_SWITCH, false) == true
    } catch (e: Exception) {
        false
    }

    /** A dev build: the own id ends in .dev **and** the switch is on; either alone is not. */
    fun isDevBuild(ownPackage: String, devSwitch: Boolean): Boolean = ownPackage.endsWith(".dev") && devSwitch

    /** The APSIRA this build may talk to. */
    fun peer(ownPackage: String, devSwitch: Boolean): String =
        if (isDevBuild(ownPackage, devSwitch)) LinkConfig.APSIRA_DEV else LinkConfig.APSIRA

    /** How an app trusts APSIRA: by name in a dev build, else by [table]'s certificate. */
    fun forPeer(ownPackage: String, devSwitch: Boolean, table: FingerprintTable = apsiraTable): Trust =
        if (isDevBuild(ownPackage, devSwitch)) DevNameTrust(setOf(LinkConfig.APSIRA_DEV)) else CertificateTrust(table)

    /** How APSIRA trusts its callers: the table's packages + .dev by name in a dev build, else by certificate. */
    fun forCallers(ownPackage: String, devSwitch: Boolean, table: FingerprintTable): Trust =
        if (isDevBuild(ownPackage, devSwitch)) DevNameTrust(table.packages.map { "$it.dev" }.toSet()) else CertificateTrust(table)
}

/** Contract §3.2's check of the caller (ContentProvider.getCallingPackage), on every call. */
object CallerCheck {
    fun allows(pm: PackageManager, caller: String?, trust: Trust): Boolean = caller != null && trust.trusts(pm, caller)
}
