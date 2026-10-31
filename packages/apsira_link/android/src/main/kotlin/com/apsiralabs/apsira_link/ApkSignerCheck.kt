// From apsira packages/apsira_link/android/src/main/kotlin/com/apsiralabs/apsira_link/LinkTrust.kt @ f69b793
package com.apsiralabs.apsira_link

import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import java.security.MessageDigest

// The signer check of an APK file before it is installed or offered (D-031:
// a release build never trusts a debug certificate), CertificateTrust's rule
// for an installed package applied to an archive: the same FingerprintTable,
// the same debug-subject refusal (isDebugSubject) and the same API 28 floor.
// An archive has no hasSigningCertificate, so the one current signer's
// SHA-256 is compared with the recorded digest here. The verdict names only
// a reason code, never the path or the certificate.

/** What [ApkSignerCheck.check] decided about one APK file. */
sealed class ApkVerdict {
    /** The archive's [packageName] is signed by its one recorded release certificate. */
    data class Trusted(val packageName: String, val versionCode: Long) : ApkVerdict()

    /**
     * Not trusted, for [reason]: `unreadable` (no archive info), `api` (below
     * API 28), `signers` (not exactly one current signer), `unrecorded` (the
     * package has no digest in the table), `debug` (the SDK debug subject, or
     * a subject that does not parse), `digest` (the signer is not the recorded one).
     */
    data class Refused(val reason: String) : ApkVerdict()
}

/** Checks an APK file's signer against a [FingerprintTable]; any failure is a [ApkVerdict.Refused]. */
object ApkSignerCheck {
    const val UNREADABLE = "unreadable"
    const val API = "api"
    const val SIGNERS = "signers"
    const val UNRECORDED = "unrecorded"
    const val DEBUG = "debug"
    const val DIGEST = "digest"

    // getPackageArchiveInfo with GET_SIGNING_CERTIFICATES, signingInfo and
    // longVersionCode are API 28: the sdkInt check comes first.
    @SuppressLint("NewApi")
    fun check(pm: PackageManager, apkPath: String, table: FingerprintTable, sdkInt: Int = Build.VERSION.SDK_INT): ApkVerdict {
        if (sdkInt < Build.VERSION_CODES.P) return ApkVerdict.Refused(API)
        val info = try {
            @Suppress("DEPRECATION")
            pm.getPackageArchiveInfo(apkPath, PackageManager.GET_SIGNING_CERTIFICATES)
        } catch (e: Exception) {
            null
        } ?: return ApkVerdict.Refused(UNREADABLE)
        val pkg: String? = info.packageName
        if (pkg.isNullOrEmpty()) return ApkVerdict.Refused(UNREADABLE)
        val signing = info.signingInfo
        val signers = signing?.apkContentsSigners.orEmpty().toList()
        val reason = checkSigners(signers, signing?.hasMultipleSigners() ?: false, table.digest(pkg))
        return if (reason == null) ApkVerdict.Trusted(pkg, info.longVersionCode) else ApkVerdict.Refused(reason)
    }

    /**
     * The decision, without Android's package manager: null when [signers] is
     * exactly one current signer ([multiple] false), [digest] is recorded, the
     * signer is not the SDK debug subject and its SHA-256 is [digest];
     * otherwise the refusal's reason.
     */
    fun checkSigners(signers: List<Signature>, multiple: Boolean, digest: ByteArray?): String? {
        if (multiple || signers.size != 1) return SIGNERS
        if (digest == null) return UNRECORDED
        val signer = signers.single()
        if (isDebugSubject(signer)) return DEBUG
        val actual = MessageDigest.getInstance("SHA-256").digest(signer.toByteArray())
        return if (MessageDigest.isEqual(actual, digest)) null else DIGEST
    }
}
