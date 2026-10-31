# apsira_link — APK files

Before installing or offering an APK file, check its signer with the same rule the link
applies to an installed package (D-031). `ApkSignerCheck.kt` takes `isDebugSubject` from
`LinkTrust.kt`, its source:

```kotlin
when (val verdict = ApkSignerCheck.check(context.packageManager, apkPath, table)) {
    is ApkVerdict.Trusted -> install(verdict.packageName, verdict.versionCode)
    is ApkVerdict.Refused -> refuse(verdict.reason)
}
```

`Trusted(packageName, versionCode)` only when Android reads the archive
(`getPackageArchiveInfo` with `GET_SIGNING_CERTIFICATES`), it has exactly one current
signer, its package has a digest in the `FingerprintTable`, and that signer is not the SDK
debug subject and has the recorded SHA-256. Otherwise `Refused(reason)`:

| Reason | When |
|---|---|
| `unreadable` | no archive info (missing, corrupt or not an APK) |
| `api` | below API 28 |
| `signers` | not exactly one current signer, or several signers |
| `unrecorded` | the package has no digest in the table, or a malformed one |
| `debug` | the signer has the subject `CN=Android Debug`, or a subject that does not parse, even when its digest is recorded |
| `digest` | the signer's SHA-256 is not the recorded one |

The check compares the current signer only; a rotated key's history is not trusted. The
decision is `ApkSignerCheck.checkSigners(signers, multiple, digest)`, which needs no
package manager. A verdict holds a reason code, never the path or the certificate.
`ApkSignerCheckTest` covers each case with the two test certificates on Robolectric's
archive info; a real archive is a device check.
