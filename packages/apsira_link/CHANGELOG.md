# Changelog

## 0.6.0 — 2026-10-31

Migration: move every apsira `ref:` to `apsira-v0.6.0`. Additive; `hello` and the trust
core keep their behaviour. **New dependency `apsira_storage`** (ruling R-2): an app adopting
`apsira_link` also takes `apsira_storage`'s plugins (D-APK-026's T2 addendum lists each
manifest entry). `crypto` is a direct dependency.

- **Transport** (T1 findings F-2, F-3): a bounded worker (2 threads) drops a call still
  queued at the 5 s deadline instead of sending it late, and answers a running one
  `no_answer`; every call acquires a `ContentProviderClient`, checks APSIRA's certificate,
  calls through that client and re-checks. Byte streams as `{stream: <handle>}`
  (`LinkStreams.kt`), with `LinkWritten`, `LinkStreamException` and
  `LinkErrorCode.storeFull`.
- **`backups.dart`**: `ApsiraBackupLink` (contract §5.2), `ChannelApsiraBackupLink`, the
  reply types; `FakeApsiraBackupLink` in `testing/fake_backup_link.dart` (D-008: delete
  removes only queued copies).
- **`archive.dart`**: `ApsiraArchiveLink` (ATRIUM's offload, `atrium-offload.md` §3),
  `ChannelApsiraArchiveLink`, `LinkArchiveItem`, `LinkArchiveEntry`, `LinkArchiveState`,
  `LinkArchiveFetch`; `FakeApsiraArchiveLink` in `testing/fake_archive_link.dart`.
- **`requests.dart`** and **`AppLinkProvider`** (Kotlin, declared by the app; contract §2,
  §5.3, §5.4): `AppLinkRequests`, `ChannelAppLinkRequests`, `RestoreOffer`,
  `AppLinkNames`, the inbox `AppLinkInbox`; `backup_now` goes to `apsira_jobs`'
  `RunJobReceiver`. Fake in `testing/fake_app_link_requests.dart`.
- **`backup_target.dart`**: `ApsiraBackupTarget`, APSIRA's adapter of `apsira_storage`'s
  unchanged `BackupTarget` (contract §5.1); `FakeApsiraBackupTarget` in
  `testing/fake_apsira_backup_target.dart`.
- **`ApkSignerCheck`** and **`ApkVerdict`** (Kotlin): the public signer check of an APK file
  (D-031's debug refusal, API 28 floor); no change for consumers.
- The example hands a backup over and takes a restore offer against the fakes, and
  declares `AppLinkProvider`.

## 0.5.0 — 2026-10-31

First release (D-APK-026): the app side of APSIRA's app link (contract `app-link.md` 1.0)
as one Flutter plugin (`pluginClass: ApsiraLinkPlugin`). Dependency `apsira_core`.

- **`ApsiraLink`** with `hello()` and **`ChannelApsiraLink`** over `apsira_link/link`
  (`call` with `method`, `version`, `extras`); no method throws, APSIRA missing is
  unavailable.
- **`LinkFailure`**: `LinkUnavailable` with every `LinkUnavailableReason` and
  `LinkCallFailed` with the six §8 `LinkErrorCode`s; `linkFailureFromWire`.
- **`LinkHello`** and **`chooseLinkVersion`**; `linkContract`, `linkVersions` (`1.0`),
  `linkControlDeadline` (5 s).
- **`linkDevSwitch`**: the `DEV_LINK` meta-data an app declares in its dev source set only.
- **`FakeApsiraLink`** (`testing.dart`). `F_APSIRA` is unset: a release app trusts no APSIRA
  yet.
- **`declaresLinkDevSwitch`** (`testing/link_release_manifest.dart`): each app's
  release-manifest test proves the switch absent with it.
- Kotlin (`com.apsiralabs.apsira_link`): **`FingerprintTable`**, **`CertificateTrust`** (refuses
  `.dev`, below API 28 and the SDK debug subject), **`DevNameTrust`**, **`LinkTrust`** (the dev
  selection: own id `.dev` and `DEV_LINK`), **`CallerCheck`** (ATRIUM's, re-homed, for APSIRA's
  provider), **`LinkClient`** and **`ApsiraLinkPlugin`**; Robolectric tests through `example/android`.

Migration: none; an app adopts it in its own adoption lane (D-APK-009).
