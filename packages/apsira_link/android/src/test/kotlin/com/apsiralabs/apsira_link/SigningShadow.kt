// From atrium android/app/src/test/kotlin/com/apsiralabs/atrium/files/StylusContractTest.kt @ 1ce8ec8
// (StylusContractTest.SigningShadow, moved to its own file unchanged).
package com.apsiralabs.apsira_link

import android.content.pm.PackageManager
import java.security.MessageDigest
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowApplicationPackageManager

// Robolectric's package manager does not implement hasSigningCertificate
// (it answers false), so this shadow gives it Android's meaning over the
// signatures installed in a test: true when [type] is CERT_INPUT_SHA256 and
// the digest is the SHA-256 of one of the package's certificates.
@Implements(className = "android.app.ApplicationPackageManager", isInAndroidSdk = false)
class SigningShadow : ShadowApplicationPackageManager() {
    @Implementation
    protected fun hasSigningCertificate(packageName: String, certificate: ByteArray, type: Int): Boolean {
        if (type != PackageManager.CERT_INPUT_SHA256) return false
        @Suppress("DEPRECATION")
        val signatures = try {
            RuntimeEnvironment.getApplication().packageManager
                .getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
        } catch (e: PackageManager.NameNotFoundException) {
            null
        } ?: return false
        return signatures.any { MessageDigest.getInstance("SHA-256").digest(it.toByteArray()).contentEquals(certificate) }
    }
}
